#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re, operator

from acdef import acdef
from formatter import formatter
from issue import Issue
from utils.defvars import builtins
from lexer import tokenizer, LINESTARTS
from validation import vsetting, vvariable, vstring, vsetting_aval

C_LF = 'f'
C_LT = 't'

C_ATSIGN = '@'
C_HYPHEN = '-'
C_DOLLARSIGN = '$'

C_PRIM_TBOOL = "true"
C_PRIM_FBOOL = "false"

r = r"(?<!\\)\$\{\s*[^}]*\s*\}"

def parser(action, text, cmdname, source, fmt, trace, igc, test):

    ttid = 0
    NEXT = []
    SCOPE = []
    branch = []
    BRANCHES = []
    oneliner = -1

    chain = []
    CCHAINS = []
    ubids = []
    excludes = []
    FLAGS = {}
    flag = {}

    setting = []
    SETTINGS = []

    variable = []
    VARIABLES = []

    USED_VARS = {}
    USER_VARS = {}
    VARSTABLE = builtins(cmdname)
    vindices = {}

    (tokens, ttypes, ttids, dtids) = tokenizer(text)

    i = 0
    l = len(tokens)

    S = {
        "tid": -1,
        "filename": source,
        "text": text,
        "LINESTARTS": LINESTARTS,
        "tokens": tokens,
        "ttypes": ttypes,
        "ttids": ttids,
        "dtids": dtids,
        "args": {
            "action": action,
            "source": source,
            "fmt": fmt,
            "trace": trace,
            "igc": igc,
            "test": test,
        },
        "ubids": ubids,
        "excludes": excludes,
        "warnings": {},
        "warn_lines": set(),
        "warn_lsort": set()
    }

    def err(tid, message, pos="start", scope=""):
        # When token ID points to end-of-parsing token,
        # reset the id to the last true token before it.
        if tokens[tid]["kind"] == "tkEOP": tid = ttids[-1]

        token = tokens[tid]
        line = token["line"]
        index = token[pos]
        # msg = f"{message}"
        col = index - LINESTARTS[line]

        if message.endswith(":"): message += f" '{tkstr(tid)}'"

        # # Add token debug information.
        # dbeugmsg = "\n\n\033[1mToken\033[0m: "
        # dbeugmsg += "\n - tid: " + str(token["tid"])
        # dbeugmsg += "\n - kind: " + token["kind"]
        # dbeugmsg += "\n - line: " + str(token["line"])
        # dbeugmsg += "\n - start: " + str(token["start"])
        # dbeugmsg += "\n - end: " + str(token["end"])
        # dbeugmsg += "\n __val__: [" + tkstr(tid) + "]"

        # dbeugmsg += "\n\n\033[1mExpected\033[0m: "
        # for n in NEXT:
        #     if not n: n = "\"\""
        #     dbeugmsg += "\n - " + n
        # dbeugmsg += "\n\n\033[1mScopes\033[0m: "
        # for s in SCOPE:
        #     dbeugmsg += "\n - " + s
        # decor = "-" * 15
        # msg += "\n\n" + decor + " TOKEN_DEBUG_INFO " + decor
        # msg += dbeugmsg
        # msg += "\n\n" + decor + " TOKEN_DEBUG_INFO " + decor

        Issue().error(S["filename"], line, col, message)

    def warn(tid, message):
        token = tokens[tid]
        line = token["line"]
        index = token["start"]
        col = index - LINESTARTS[line]

        if message.endswith(":"): message += f" '{tkstr(tid)}'"

        if line not in S["warnings"]: S["warnings"][line] = []
        S["warnings"][line].append([S["filename"], line, col, message])
        S["warn_lines"].add(line)

    def hint(tid, message):
        token = tokens[tid]
        line = token["line"]
        index = token["start"]
        col = index - LINESTARTS[line]

        if message.endswith(":"): message += f" '{tkstr(tid)}'"

        Issue().hint(S["filename"], line, col, message)

    def tkstr(tid):
        if tid == -1: return ""
        if tokens[tid]["kind"] == "tkSTR":
            if "$" in tokens[tid]: return tokens[tid]["$"]
        return text[tokens[tid]["start"]:tokens[tid]["end"] + 1]

    def addtoken(i):

        # Interpolate/track interpolation indices for string.
        if tokens[i]["kind"] == "tkSTR":

            value = tkstr(i)
            tokens[i]["$"] = value

            if i not in vindices:
                end = 0
                pointer = 0
                tmpstr = ""
                vindices[i] = []

                # [https://stackoverflow.com/a/3519601]
                # [https://docs.python.org/2/library/re.html#re.finditer]
                for match in re.finditer(r, value):
                    start = match.span()[0]
                    end = len(match.group()) + start
                    varname = match.group()[2:-1].strip()

                    if varname not in VARSTABLE:
                        # Note: Modify token index to point to
                        # start of the variable position.
                        tokens[S["tid"]]["start"] += start
                        err(ttid, "Undefined variable", scope="child")

                    USED_VARS[varname] = 1
                    vindices[i].append([start, end])

                    tmpstr += value[pointer:start]
                    sub = VARSTABLE.get(varname, "")
                    # Unquote string if quoted.
                    tmpstr += sub if sub[0] not in ("\"", "'") else sub[1:-1]
                    pointer = end

                # Get tail-end of string.
                tmpstr += value[end:]
                tokens[i]["$"] = tmpstr

                if not vindices[i]: del vindices[i]

        nonlocal branch
        branch.append(tokens[i])

    def expect(*args):
        nonlocal NEXT
        NEXT.clear()
        for a in args:
            NEXT.append(a)

    def clearscope():
        nonlocal SCOPE
        SCOPE.clear()

    def addscope(s):
        nonlocal SCOPE
        SCOPE.append(s)

    def popscope(pops = 1):
        nonlocal SCOPE
        while pops:
            SCOPE.pop()
            pops -= 1

    def hasscope(s):
        return s in SCOPE

    def prevscope():
        return SCOPE[-1]

    def hasnext(s):
        return s in NEXT

    def nextany():
        return NEXT[0] == ""

    def addbranch(b):
        nonlocal BRANCHES
        BRANCHES.append(b)

    def newbranch():
        nonlocal branch
        branch = []

    def prevtoken():
        return tokens[dtids[S["tid"]]]

    # Command chain/flag grouping helpers.
    # ================================

    def newgroup():
        nonlocal chain
        chain = []

    def addtoken_group(i):
        nonlocal chain
        chain.append(i)

    def addgroup(g):
        nonlocal CCHAINS
        CCHAINS.append([g])

    def addtoprevgroup():
        nonlocal chain, CCHAINS
        newgroup()
        CCHAINS[-1].append(chain)

    # ============================

    def newflag():
        nonlocal flag, FLAGS
        flag = {
            "tid": -1,
            "alias": -1,
            "boolean": -1,
            "assignment": -1,
            "multi": -1,
            "union": -1,
            "values": []
        }
        setflagprop("tid")
        index = len(CCHAINS) - 1
        if index not in FLAGS:
            FLAGS[index] = []
        FLAGS[index].append(flag)

    def newvaluegroup(prop):
        nonlocal flag
        flag[prop].append([-1])

    def setflagprop(prop, prev_val_group = False):
        nonlocal flag
        if prop != "values":
            flag[prop] = S["tid"]
        else:
            if not prev_val_group:
                flag[prop].append([S["tid"]])
            else:
                flag[prop][-1].append(S["tid"])

    # Setting/variable grouping helpers.
    # ================================

    def newgroup_stn():
        nonlocal setting
        setting = []

    def addtoken_stn_group(i):
        nonlocal setting
        setting.append(i)

    def addgroup_stn(g):
        nonlocal SETTINGS
        SETTINGS.append(g)

    # def addtoprevgroup_stn():
    #     nonlocal setting, SETTINGS
    #     newgroup_stn()
    #     SETTINGS[-1].append(setting)

    # ============================

    def newgroup_var():
        nonlocal variable
        variable = []

    def addtoken_var_group(i):
        nonlocal variable
        variable.append(i)

    def addgroup_var(g):
        nonlocal VARIABLES
        VARIABLES.append(g)

    # def addtoprevgroup_var():
    #     nonlocal variable, VARIABLES
    #     newgroup_var()
    #     VARIABLES[-1].append(variable)

    # ============================

    def __stn__asg(kind):
        addtoken_stn_group(S["tid"])

        expect("tkSTR", "tkAVAL")

    def __stn__str(kind):
        addtoken_stn_group(S["tid"])

        expect("")

        vstring(S)

    def __stn__aval(kind):
        addtoken_stn_group(S["tid"])

        expect("")

        vsetting_aval(S)

    def __var__asg(kind):
        addtoken_var_group(S["tid"])

        expect("tkSTR")

    def __var__str(kind):
        addtoken_var_group(S["tid"])
        VARSTABLE[tkstr(branch[-3]["tid"])[1:]] = tkstr(S["tid"])

        expect("")

        vstring(S)

    def __cmd__asg(kind):

        # If a universal block, store group id.
        if S["tid"] in dtids:
            prevtk = prevtoken()
            if prevtk["kind"] == "tkCMD" and text[prevtk["start"]] == "*":
                ubids.append(len(CCHAINS) - 1)
        expect("tkBRC_LB", "tkFLG", "tkKYW")

    def __cmd__brc_lb(kind):
        addscope(kind)
        expect("tkFLG", "tkKYW", "tkBRC_RB")

    # # [TODO] Pathway needed?
    # def __cmd__brc_rb(kind):
    #     expect("", "tkCMD")

    def __cmd__flg(kind):
        newflag()

        addscope(kind)
        expect("", "tkASG", "tkQMK", "tkDCLN",
            "tkFVAL", "tkDPPE", "tkBRC_RB")

    def __cmd__kyw(kind):
        newflag()

        addscope(kind)
        expect("tkSTR", "tkDLS")

    def __cmd__ddot(kind):
        expect("tkCMD", "tkBRC_LC")

    def __cmd__cmd(kind):
        addtoken_group(S["tid"])

        expect("", "tkDDOT", "tkASG", "tkDCMA")

    def __cmd__brc_lc(kind):
        addtoken_group(-1)

        addscope(kind)
        expect("tkCMD")

    def __cmd__dcma(kind):

        # If a universal block, store group id.
        if S["tid"] in dtids:
            prevtk = prevtoken()
            if prevtk["kind"] == "tkCMD" and text[prevtk["start"]] == "*":
                ubids.append(len(CCHAINS) - 1)
        addtoprevgroup()

        addscope(kind)
        expect("tkCMD")

    def __brc_lc__cmd(kind):
        addtoken_group(S["tid"])

        expect("tkDCMA", "tkBRC_RC")

    def __brc_lc__dcma(kind):
        expect("tkCMD")

    def __brc_lc__brc_rc(kind):
        addtoken_group(-1)

        popscope()
        expect("", "tkDDOT", "tkASG", "tkDCMA")

    def __flg__dcln(kind):
        if prevtoken()["kind"] != "tkDCLN":
            expect("tkDCLN")
        else:
            expect("tkFLGA")

    def __flg__flga(kind):
        setflagprop("alias")

        expect("", "tkASG", "tkQMK", "tkDPPE")

    def __flg__qmk(kind):
        setflagprop("boolean")

        expect("", "tkDPPE")

    def __flg__asg(kind):
        setflagprop("assignment")

        expect("", "tkDCMA", "tkMTL", "tkDPPE", "tkBRC_LP",
            "tkFVAL", "tkSTR", "tkDLS", "tkBRC_RB")

    def __flg__dcma(kind):
        setflagprop("union")

        expect("tkFLG", "tkKYW")

    def __flg__mtl(kind):
        setflagprop("multi")

        expect("", "tkBRC_LP", "tkDPPE")

    def __flg__dls(kind):
        addscope(kind) # Build cmd-string.
        expect("tkBRC_LP")

    def __flg__brc_lp(kind):
        addscope(kind)
        expect("tkFVAL", "tkSTR", "tkFOPT", "tkDLS", "tkBRC_RP")

    def __flg__flg(kind):
        newflag()

        if hasscope("tkBRC_LB") and token["line"] == prevtoken()["line"]:
            err(S["tid"], "Flag same line (nth)", scope="child")
        expect("", "tkASG", "tkQMK",
            "tkDCLN", "tkFVAL", "tkDPPE")

    def __flg__kyw(kind):
        newflag()

        # [TODO] Investigate why leaving flag scope doesn't affect
        # parsing. For now remove it to keep scopes array clean.
        popscope()

        if hasscope("tkBRC_LB") and token["line"] == prevtoken()["line"]:
            err(S["tid"], "Keyword same line (nth)", scope="child")
        addscope(kind)
        expect("tkSTR", "tkDLS")

    def __flg__str(kind):
        setflagprop("values")

        expect("", "tkDPPE")

    def __flg__fval(kind):
        setflagprop("values")

        expect("", "tkDPPE")

    def __flg__dppe(kind):
        expect("tkFLG", "tkKYW")

    def __flg__brc_rb(kind):
        popscope()
        expect("")

    def __brc_lp__fopt(kind):
        prevtk = prevtoken()
        if prevtk["kind"] == "tkBRC_LP":
            if prevtk["line"] == line:
                err(S["tid"], "Option same line (first)", scope="child")
            addscope("tkOPTS")
            expect("tkFVAL", "tkSTR", "tkDLS")

    def __brc_lp__fval(kind):
        setflagprop("values")

        expect("tkFVAL", "tkSTR", "tkDLS", "tkBRC_RP", "tkTBD")

    # Disable pathway for now.
    # def __brc_lp__tbd(kind):
    #     setflagprop("values")

    #     expect("tkFVAL", "tkSTR", "tkDLS", "tkBRC_RP", "tkTBD")

    def __brc_lp__str(kind):
        setflagprop("values")

        expect("tkFVAL", "tkSTR", "tkDLS", "tkBRC_RP", "tkTBD")

    def __brc_lp__dls(kind):
        addscope(kind)
        expect("tkBRC_LP")

    # # [TODO] Pathway needed?
    # def __brc_lp__dcma(kind):
    #     expect("tkFVAL", "tkSTR")

    def __brc_lp__brc_rp(kind):
        popscope()
        expect("", "tkDPPE")

        prevtk = prevtoken()
        if prevtk["kind"] == "tkBRC_LP":
            warn(prevtk["tid"], "Empty scope (flag)")

    # # [TODO] Pathway needed?
    # def __brc_lp__brc_rb(kind):
    #     popscope()
    #     expect("")

    def __dls__brc_lp(kind):
        newvaluegroup("values")
        setflagprop("values", prev_val_group=True)

        expect("tkSTR")

    def __dls__dls(kind):
        expect("tkSTR")

    def __dls__str(kind):
        expect("tkDCMA", "tkBRC_RP")

    def __dls__dcma(kind):
        expect("tkSTR", "tkDLS")

    def __dls__brc_rp(kind):
        popscope()

        setflagprop("values", prev_val_group=True)

        # Handle: 'program = --flag=$("cmd")'
        # Handle: 'program = default $("cmd")'
        if prevscope() in ("tkFLG", "tkKYW"):
            if hasscope("tkBRC_LB"):
                popscope()
                expect("tkFLG", "tkKYW", "tkBRC_RB")
            else:
                # Handle: oneliner command-string
                # 'program = --flag|default $("cmd", $"c", "c")'
                # 'program = --flag::f=(1 3)|default $("cmd")|--flag'
                # 'program = --flag::f=(1 3)|default $("cmd")|--flag'
                # 'program = default $("cmd")|--flag::f=(1 3)'
                # 'program = default $("cmd")|--flag::f=(1 3)|default $("cmd")'
                expect("", "tkDPPE", "tkFLG", "tkKYW")

        # Handle: 'program = --flag=(1 2 3 $("c") 4)'
        elif prevscope() in ("tkBRC_LP"):
            expect("tkFVAL", "tkSTR", "tkFOPT", "tkDLS", "tkBRC_RP")

        # Handle: long-form
        # 'program = [
        #      --flag=(
        #          - 1
        #          - $("cmd")
        #          - true
        #      )
        #  ]'
        elif prevscope() in ("tkOPTS"):
            expect("tkFOPT", "tkBRC_RP")

    def __opts__fopt(kind):
        if prevtoken()["line"] == line:
            err(S["tid"], "Option same line (nth)", scope="child")
        expect("tkFVAL", "tkSTR", "tkDLS")

    def __opts__dls(kind):
        addscope("tkDLS") # Build cmd-string.
        expect("tkBRC_LP")

    def __opts__fval(kind):
        setflagprop("values")

        expect("tkFOPT", "tkBRC_RP")

    def __opts__str(kind):
        setflagprop("values")

        expect("tkFOPT", "tkBRC_RP")

    def __opts__brc_rp(kind):
        popscope(2)
        expect("tkFLG", "tkKYW", "tkBRC_RB")

    def __brc_lb__flg(kind):
        newflag()

        if hasscope("tkBRC_LB") and token["line"] == prevtoken()["line"]:
            err(S["tid"], "Flag same line (first)", scope="child")
        addscope(kind)
        expect("tkASG", "tkQMK", "tkDCLN",
            "tkFVAL", "tkDPPE", "tkBRC_RB")

    def __brc_lb__kyw(kind):
        newflag()

        if hasscope("tkBRC_LB") and token["line"] == prevtoken()["line"]:
            err(S["tid"], "Keyword same line (first)", scope="child")
        addscope(kind)
        expect("tkSTR", "tkDLS", "tkBRC_RB")

    def __brc_lb__brc_rb(kind):
        popscope()
        expect("")

        prevtk = prevtoken()
        if prevtk["kind"] == "tkBRC_LB":
            warn(prevtk["tid"], "Empty scope (command)")

    def __kyw__str(kind):
        setflagprop("values")

        # Collect exclude values for use upstream.
        if S["tid"] in dtids:
            prevtk = prevtoken()
            if (prevtk["kind"] == "tkKYW" and
                tkstr(prevtk["tid"]) == "exclude"):
                excl_values = tkstr(S["tid"])[1:-1].strip().split(";")
                for exclude in excl_values: excludes.append(exclude)

        # [TODO] This pathway re-uses the flag (tkFLG) token
        # pathways. If the keyword syntax were to change
        # this will need to change as it might no loner work.
        popscope()
        addscope("tkFLG") # Re-use flag pathways for now.
        expect("", "tkDPPE")

    def __kyw__dls(kind):
        addscope(kind) # Build cmd-string.
        expect("tkBRC_LP")

    # # [TODO] Pathway needed?
    # def __kyw__brc_rb(kind):
    #     popscope()
    #     expect("")

    # # [TODO] Pathway needed?
    # def __kyw__flg(kind):
    #     expect("tkASG", "tkQMK",
    #         "tkDCLN", "tkFVAL", "tkDPPE")

    # # [TODO] Pathway needed?
    # def __kyw__kyw(kind):
    #     addscope(kind)
    #     expect("tkSTR", "tkDLS")

    def __kyw__dppe(kind):
        # [TODO] Because the flag (tkFLG) token pathways are
        # reused for the keyword (tkKYW) pathways, the scope
        # needs to be removed. This is fine for now but when
        # the keyword token pathway change, the keyword
        # pathways will need to be fleshed out in the future.
        if prevscope() in ("tkKYW"):
            popscope()
            addscope("tkFLG") # Re-use flag pathways for now.
        expect("tkFLG", "tkKYW")

    def __dcma__cmd(kind):
        addtoken_group(S["tid"])

        popscope()
        expect("", "tkDDOT", "tkASG", "tkDCMA")

        command = tkstr(S["tid"])
        if command != "*" and command != cmdname:
            warn(S["tid"], "Unexpected command:")

    DISPATCH = {
        "tkSTN": {
            "tkASG": __stn__asg,
            "tkSTR": __stn__str,
            "tkAVAL": __stn__aval,
        },
        "tkVAR": {
            "tkASG": __var__asg,
            "tkSTR": __var__str
        },
        "tkCMD": {
            "tkASG": __cmd__asg,
            "tkBRC_LB": __cmd__brc_lb,
            # "tkBRC_RB": __cmd__brc_rb,
            "tkFLG": __cmd__flg,
            "tkKYW": __cmd__kyw,
            "tkDDOT": __cmd__ddot,
            "tkCMD": __cmd__cmd,
            "tkBRC_LC": __cmd__brc_lc,
            "tkDCMA": __cmd__dcma
        },
        "tkBRC_LC": {
            "tkCMD": __brc_lc__cmd,
            "tkDCMA": __brc_lc__dcma,
            "tkBRC_RC": __brc_lc__brc_rc
        },
        "tkFLG": {
            "tkDCLN": __flg__dcln,
            "tkFLGA": __flg__flga,
            "tkQMK": __flg__qmk,
            "tkASG": __flg__asg,
            "tkDCMA": __flg__dcma,
            "tkMTL": __flg__mtl,
            "tkDLS": __flg__dls,
            "tkBRC_LP": __flg__brc_lp,
            "tkFLG": __flg__flg,
            "tkKYW": __flg__kyw,
            "tkSTR": __flg__str,
            "tkFVAL": __flg__fval,
            "tkDPPE": __flg__dppe,
            "tkBRC_RB": __flg__brc_rb
        },
        "tkBRC_LP": {
            "tkFOPT": __brc_lp__fopt,
            "tkFVAL": __brc_lp__fval,
            # "tkTBD": __brc_lp__tbd,
            "tkSTR": __brc_lp__str,
            "tkDLS": __brc_lp__dls,
            # "tkDCMA": __brc_lp__dcma,
            "tkBRC_RP": __brc_lp__brc_rp
            # "tkBRC_RB": __brc_lp__brc_rb
        },
        "tkDLS": {
            "tkBRC_LP": __dls__brc_lp,
            "tkDLS": __dls__dls,
            "tkSTR": __dls__str,
            "tkDCMA": __dls__dcma,
            "tkBRC_RP": __dls__brc_rp
        },
        "tkOPTS": {
            "tkFOPT": __opts__fopt,
            "tkDLS": __opts__dls,
            "tkFVAL": __opts__fval,
            "tkSTR": __opts__str,
            "tkBRC_RP": __opts__brc_rp
        },
        "tkBRC_LB": {
            "tkFLG": __brc_lb__flg,
            "tkKYW": __brc_lb__kyw,
            "tkBRC_RB": __brc_lb__brc_rb,
        },
        "tkKYW": {
            "tkSTR": __kyw__str,
            "tkDLS": __kyw__dls,
            # "tkFLG": __kyw__flg,
            # "tkKYW": __kyw__kyw,
            # "tkBRC_RB": __kyw__brc_rb,
            "tkDPPE": __kyw__dppe,
        },
        "tkDCMA": {
            "tkCMD": __dcma__cmd
        }
    }

    while i < l:
        token = tokens[i]
        kind = token["kind"]
        line = token["line"]
        start = token["start"]
        end = token["end"]
        S["tid"] = token["tid"]

        if kind == "tkNL":
            i += 1
            continue

        if kind != "tkEOP":
            ttid = i

        if kind == "tkTRM":
            addtoken(ttid)

            if not SCOPE:
                addbranch(branch)
                newbranch()
                expect("")
            else:
                if NEXT and not nextany():
                    err(ttid, "Improper termination", scope="child")

            i += 1
            continue

        if not SCOPE:

            if kind != "tkEOP":
                addtoken(ttid)

            if BRANCHES:
                ltoken = BRANCHES[-1][-1] # Last branch token.
                if line == ltoken["line"] and ltoken["kind"] != "tkTRM":
                    err(ttid, "Improper termination", scope="parent")

            oneliner = -1

            if kind != "tkEOP":
                if kind in ("tkSTN", "tkVAR", "tkCMD"):
                    addbranch(branch)
                    addscope(kind)
                    if kind == "tkSTN":
                        newgroup_stn()
                        addgroup_stn(setting)
                        addtoken_stn_group(S["tid"])

                        vsetting(S)
                        expect("", "tkASG")
                    elif kind == "tkVAR":
                        newgroup_var()
                        addgroup_var(variable)
                        addtoken_var_group(S["tid"])

                        varname = tkstr(S["tid"])[1:]
                        VARSTABLE[varname] = ""

                        if varname not in USER_VARS:
                            USER_VARS[varname] = []
                        USER_VARS[varname].append(S["tid"])

                        vvariable(S)
                        expect("", "tkASG")
                    elif kind == "tkCMD":
                        addtoken_group(S["tid"])
                        addgroup(chain)

                        expect("", "tkDDOT", "tkASG", "tkDCMA")

                        command = tkstr(S["tid"])
                        if command != "*" and command != cmdname:
                            warn(S["tid"], "Unexpected command:")
                else:
                    if kind == "tkCMT":
                        addbranch(branch)
                        newbranch()
                        expect("")
                    else: # Handle unexpected parent tokens.
                        err(S["tid"], "Unexpected token:", scope="parent")

        else:

            if kind == "tkCMT":
                addtoken(ttid)
                i += 1
                continue

            # Remove/add necessary tokens when parsing long flag form.
            if hasscope("tkBRC_LB"):
                if hasnext("tkDPPE"):
                    NEXT.remove("tkDPPE")
                    NEXT.append("tkFLG")
                    NEXT.append("tkKYW")
                    NEXT.append("tkBRC_RB")

            if NEXT and not hasnext(kind):
                if nextany():
                    clearscope()
                    newbranch()

                    newgroup()
                    continue

                else:
                    err(S["tid"], "Unexpected token:", scope="child")

            addtoken(ttid)

            # Oneliners must be declared on oneline, else error.
            if branch[0]["kind"] == "tkCMD" and (
                ((hasscope("tkFLG") or hasscope("tkKYW"))
                or kind in ("tkFLG", "tkKYW"))
                and not hasscope("tkBRC_LB")):
                if oneliner == -1: oneliner = token["line"]
                elif token["line"] != oneliner:
                    err(S["tid"], "Improper oneliner", scope="child")

            if kind in DISPATCH[prevscope()]:
                DISPATCH[prevscope()][kind](kind)
            else: err(tokens[S["tid"]]["tid"], "Unexpected token:", pos="end")

        i += 1

    # Check for any unused variables and give warning.
    for uservar in USER_VARS:
        if uservar not in USED_VARS:
            for tid in USER_VARS[uservar]:
                warn(tid, f"Unused variable: '{uservar}'")
                S["warn_lsort"].add(tokens[tid]["line"])

    # Sort warning lines and print issues.
    warnlines = list(S["warn_lines"])
    warnlines.sort()
    for warnline in warnlines:
        # Only sort lines where unused variable warning(s) were added.
        if warnline in S["warn_lsort"] and len(S["warnings"][warnline]) > 1:
            # [https://stackoverflow.com/a/4233482]
            S["warnings"][warnline].sort(key = operator.itemgetter(1, 2))
        for warning in S["warnings"][warnline]:
            Issue().warn(*warning)

    if action == "make": return acdef(BRANCHES, CCHAINS, FLAGS, SETTINGS, S)
    else: return formatter(tokens, text, BRANCHES, CCHAINS, FLAGS, SETTINGS, S)
