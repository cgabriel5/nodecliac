#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re

from acdef import acdef
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
    FLAGS = {}
    flag = {}

    setting = []
    SETTINGS = []
    variable = []
    VARIABLES = []
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
        "args": {
            "action": action,
            "source": source,
            "fmt": fmt,
            "trace": trace,
            "igc": igc,
            "test": test,
        }
    }

    def err(tid, etype, message):
        # When token ID points to end-of-parsing token,
        # reset the id to the last true token before it.
        if tokens[tid]["kind"] == "tkEOP":
            tid = ttids[-1]

        token = tokens[tid]
        line = token["line"]
        index = token["start" if etype != "<term>" else "end"]
        msg = f"{etype} {message}"

        # Add token debug information.
        dbeugmsg = "\n\n\033[1mToken\033[0m: "
        dbeugmsg += "\n - tid: " + str(token["tid"])
        dbeugmsg += "\n - kind: " + token["kind"]
        dbeugmsg += "\n - line: " + str(token["line"])
        dbeugmsg += "\n - start: " + str(token["start"])
        dbeugmsg += "\n - end: " + str(token["end"])
        dbeugmsg += "\n __val__: [" + tkstr(tid) + "]"

        dbeugmsg += "\n\n\033[1mExpected\033[0m: "
        for n in NEXT:
            if not n: n = "\"\""
            dbeugmsg += "\n - " + n
        dbeugmsg += "\n\n\033[1mScopes\033[0m: "
        for s in SCOPE:
            dbeugmsg += "\n - " + s
        decor = "-" * 15
        msg += "\n\n" + decor + " TOKEN_DEBUG_INFO " + decor
        msg += dbeugmsg
        msg += "\n\n" + decor + " TOKEN_DEBUG_INFO " + decor

        Issue().error(S["filename"], line, index - LINESTARTS[line], msg)

    def warn(tid, message):
        token = tokens[tid]
        line = token["line"]
        index = token["start"]

        Issue().warn(filename, line, index - LINESTARTS[line], message)

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
                        err(ttid, "<child>", "Undefined variable.")

                    vindices[i].append([start, end])

                    tmpstr += value[pointer:start]
                    tmpstr += VARSTABLE.get(varname, "")[1:-1]
                    pointer = end + 1

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

    def addtoprevgroup_stn():
        nonlocal setting, SETTINGS
        newgroup_stn()
        SETTINGS[-1].append(setting)

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

    def addtoprevgroup_var():
        nonlocal variable, VARIABLES
        newgroup_var()
        VARIABLES[-1].append(variable)

    # ============================

    def __stn__asg(kind):
        addtoken_stn_group(S["tid"])

        expect("tkSTR", "tkAVAL")

    def __stn__str(kind):
        addtoken_stn_group(S["tid"])

        clearscope()
        newbranch()

        vstring(S)

    def __stn__aval(kind):
        addtoken_stn_group(S["tid"])

        clearscope()
        newbranch()

        vsetting_aval(S)

    def __var__asg(kind):
        addtoken_var_group(S["tid"])

        expect("tkSTR")

    def __var__str(kind):
        addtoken_var_group(S["tid"])
        VARSTABLE[tkstr(branch[-3]["tid"])[1:]] = tkstr(S["tid"])

        clearscope()
        newbranch()

        vstring(S)

    def __cmd__asg(kind):
        expect("tkBRC_LB", "tkFLG", "tkKYW")

    def __cmd__brc_lb(kind):
        addscope(kind)
        expect("tkFLG", "tkKYW", "tkBRC_RB")

    def __cmd__brc_rb(kind):
        expect("", "tkCMD")

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
            err(S["tid"], "<child>", "err: Flag same line (nth)")
        expect("", "tkASG", "tkQMK",
            "tkDCLN", "tkFVAL", "tkDPPE")

    def __flg__kyw(kind):
        newflag()

        if hasscope("tkBRC_LB") and token["line"] == prevtoken()["line"]:
            err(S["tid"], "<child>", "err: Keyword same line (nth)")
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
                err(S["tid"], "<child>", "err: Option on same line (first)")
            addscope("tkOPTS")
            expect("tkFVAL", "tkSTR", "tkDLS")

    def __brc_lp__fval(kind):
        setflagprop("values")

        expect("tkFVAL", "tkSTR", "tkDLS", "tkBRC_RP")

    def __brc_lp__str(kind):
        setflagprop("values")

        expect("tkFVAL", "tkSTR", "tkDLS", "tkBRC_RP")

    def __brc_lp__dls(kind):
        addscope(kind)
        expect("tkBRC_LP")

    def __brc_lp__dcma(kind):
        expect("tkFVAL", "tkSTR")

    def __brc_lp__brc_rp(kind):
        popscope()
        expect("", "tkDPPE")

        prevtk = prevtoken()
        if prevtk["kind"] == "tkBRC_LP":
            warn(prevtk["tid"], "Empty scope (flag)")

    def __brc_lp__brc_rb(kind):
        popscope()
        expect("")

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

        if prevscope() == "tkOPTS":
            expect("tkFVAL", "tkBRC_RP")
        else:
            if prevscope() in ("tkFLG", "tkKYW"):
                if hasscope("tkBRC_LB"):
                    popscope()
                    expect("tkDPPE", "tkBRC_RB")
                else:
                    expect("", "tkDPPE", "tkFLG", "tkKYW")
            else:
                # Handle: 'program = --flag=(1 2 $("cmd"))'
                # or: 'program = --command=$("cmd")'
                expect("", "tkFVAL", "tkSTR", "tkDLS", "tkBRC_RP")

    def __opts__fopt(kind):
        if prevtoken()["line"] == line:
            err(S["tid"], "<child>", "err: Option on same line (nth)")
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
            err(S["tid"], "<child>", "err: Flag same line (first)")
        addscope(kind)
        expect("tkASG", "tkQMK", "tkDCLN",
            "tkFVAL", "tkDPPE", "tkBRC_RB")

    def __brc_lb__kyw(kind):
        newflag()

        if hasscope("tkBRC_LB") and token["line"] == prevtoken()["line"]:
            err(S["tid"], "<child>", "err: Keyword same line (first)")
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

        popscope()
        addscope("tkFLG") # Re-use flag pathways for now.
        expect("", "tkDPPE")

    def __kyw__dls(kind):
        addscope(kind) # Build cmd-string.
        expect("tkBRC_LP")

    def __kyw__brc_rb(kind):
        popscope()
        expect("")

    def __kyw__flg(kind):
        expect("tkASG", "tkQMK",
            "tkDCLN", "tkFVAL", "tkDPPE")

    def __kyw__kyw(kind):
        addscope(kind)
        expect("tkSTR", "tkDLS")

    def __kyw__dppe(kind):
        expect("tkFLG", "tkKYW")

    def __dcma__cmd(kind):
        addtoken_group(S["tid"])

        popscope()
        expect("", "tkDDOT", "tkASG", "tkDCMA")

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
            "tkBRC_RB": __cmd__brc_rb,
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
            "tkSTR": __brc_lp__str,
            "tkDLS": __brc_lp__dls,
            "tkDCMA": __brc_lp__dcma,
            "tkBRC_RP": __brc_lp__brc_rp,
            "tkBRC_RB": __brc_lp__brc_rb
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
            "tkFLG": __kyw__flg,
            "tkKYW": __kyw__kyw,
            "tkBRC_RB": __kyw__brc_rb,
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
                    err(ttid, "<child>", "Improper termination")

            i += 1
            continue

        if not SCOPE:

            if kind != "tkEOP":
                addtoken(ttid)

            if BRANCHES:
                ltoken = BRANCHES[-1][-1] # Last branch token.
                if line == ltoken["line"] and ltoken["kind"] != "tkTRM":
                    err(ttid, "<parent>", "Improper termination")

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
                        VARSTABLE[tkstr(S["tid"])[1:]] = ""

                        vvariable(S)
                        expect("", "tkASG")
                    elif kind == "tkCMD":
                        addtoken_group(S["tid"])
                        addgroup(chain)

                        expect("", "tkDDOT", "tkASG", "tkDCMA")
                else:
                    if kind == "tkCMT":
                        addbranch(branch)
                        newbranch()
                        expect("")
                    else: # Handle unexpected parent tokens.
                        err(S["tid"], "<parent>", "Unexpected parent token.")

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
                    err(S["tid"], "<child>", "Unexpected child token.")

            addtoken(ttid)

            # Oneliners must be declared on oneline, else error.
            if branch[0]["kind"] == "tkCMD" and (
                ((hasscope("tkFLG") or hasscope("tkKYW"))
                or kind in ("tkFLG", "tkKYW"))
                and not hasscope("tkBRC_LB")):
                if oneliner == -1: oneliner = token["line"]
                elif token["line"] != oneliner:
                    err(S["tid"], "<child>", "Improper oneliner.")

            # [TODO] Improve this error handling.
            if kind in DISPATCH[prevscope()]:
                DISPATCH[prevscope()][kind](kind)
            else:
                err(tokens[S["tid"]]["tid"], "<term>", f"Try/catch {kind}")

        i += 1

    if action == "make":
        return acdef(BRANCHES, CCHAINS, FLAGS, SETTINGS, S)
    # [TODO] Formatter
