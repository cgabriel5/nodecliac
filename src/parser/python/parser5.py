#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys, json

from lexer import tokenizer, LINESTARTS
# from pathlib import Path  # [https://stackoverflow.com/a/66195538]

C_LF = 'f'
C_LT = 't'

C_ATSIGN = '@'
C_HYPHEN = '-'
C_DOLLARSIGN = '$'

C_PRIM_TBOOL = "true"
C_PRIM_FBOOL = "false"

def main():
    if __name__ == "__main__":

        # hdir = str(Path.home())
        # f = open(hdir + "/.nodecliac/registry/nodecliac/nodecliac.acmap", "r")
        # text = f.read()

        # f = open("../../../resources/packages/nodecliac/nodecliac.acmap", "r")
        # text = f.read()

        text = """a.b{c}.d.{e} o.pop @setting"""

        (tokens, ttypes) = tokenizer(text)

        def err(tid, etype, message):
            token = tokens[tid]
            line = token["line"]
            index = token["start" if etype != "<term>" else "end"]

            sys.exit("\033[1mdep.acmap:" +
                    f"{line}:{index - LINESTARTS[line]}:" +
                    f"\033[0m \033[31;1merror:\033[0m {etype} {message}")

        def completing(kind):
            return SCOPE[-1] == kind

        def addtoken(i):
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

        def popscope():
            nonlocal SCOPE
            SCOPE.pop()

        def addbranch(b):
            nonlocal AST
            AST.append(b)

        def newbranch():
            nonlocal branch
            branch = []

        # ============================

        def __stn__asg(kind):
            expect("tkSTR", "tkAVAL")

        def __stn__str(kind):
            clearscope()
            newbranch()

        def __stn__aval(kind):
            clearscope()
            newbranch()

        def __var__asg(kind):
            expect("tkSTR")

        def __var__str(kind):
            clearscope()
            newbranch()

        def __cmd__asg(kind):
            expect("tkBRC_LB", "tkFLG", "tkKYW")

        def __cmd__brc_lb(kind):
            addscope(kind)
            expect("tkFLG", "tkKYW")

        def __cmd__brc_rb(kind):
            expect("", "tkCMD")

        def __cmd__flg(kind):
            addscope(kind)
            expect("", "tkASG", "tkQMK", "tkDCLN",
                "tkFVAL", "tkDPPE", "tkBRC_RB")

        def __cmd__kyw(kind):
            addscope(kind)
            expect("tkSTR", "tkDLS")

        def __cmd__ddot(kind):
            expect("tkCMD", "tkBRC_LC")

        def __cmd__cmd(kind):
            expect("", "tkDDOT", "tkASG", "tkDCMA")

        def __cmd__brc_lc(kind):
            addscope(kind)
            expect("tkCMD")

        def __cmd__dcma(kind):
            addscope(kind)
            expect("tkCMD")

        def __brc_lc__cmd(kind):
            expect("tkDCMA", "tkBRC_RC")

        def __brc_lc__dcma(kind):
            expect("tkCMD")

        def __brc_lc__brc_rc(kind):
            popscope()
            expect("", "tkDDOT", "tkASG")

        def __flg__dcln(kind):
            if branch[-2]["kind"] != "tkDCLN":
                expect("tkDCLN")
            else:
                expect("", "tkFLGA")

        def __flg__flga(kind):
            expect("", "tkASG", "tkQMK", "tkDPPE")

        def __flg__qmk(kind):
            expect("", "tkDPPE")

        def __flg__asg(kind):
            expect("", "tkMTL", "tkDPPE", "tkBRC_LP",
                "tkFVAL", "tkSTR", "tkDLS", "tkBRC_RB")

        def __flg__mtl(kind):
            expect("", "tkBRC_LP", "tkDPPE")

        def __flg__dls(kind):
            addscope(kind) # Build cmd-string.
            expect("tkBRC_LP")

        def __flg__brc_lp(kind):
            addscope(kind)
            expect("tkFVAL", "tkSTR", "tkFOPT")

        def __flg__flg(kind):
            expect("", "tkASG", "tkQMK",
                "tkDCLN", "tkFVAL", "tkDPPE")

        def __flg__kyw(kind):
            addscope(kind)
            expect("tkSTR", "tkDLS")

        def __flg__str(kind):
            expect("", "tkDPPE")

        def __flg__fval(kind):
            expect("", "tkDPPE")

        def __flg__dppe(kind):
            expect("tkFLG", "tkKYW")

        def __flg__brc_rb(kind):
            popscope()
            expect("")

        def __brc_lp__fopt(kind):
            # [TODO] Make this code robust.
            if branch[-2]["kind"] == "tkBRC_LP":
                if branch[-2]["line"] == line:
                    print("err: Option on same line (first)")
                addscope("tkOPTS")
                expect("tkFVAL", "tkSTR", "tkDLS")

        def __brc_lp__fval(kind):
            expect("tkFVAL", "tkSTR", "tkBRC_RP")

        def __brc_lp__str(kind):
            expect("tkFVAL", "tkSTR", "tkBRC_RP")

        def __brc_lp__dcma(kind):
            expect("tkFVAL", "tkSTR")

        def __brc_lp__brc_rp(kind):
            popscope()
            expect("", "tkDPPE")

        def __brc_lp__brc_rb(kind):
            popscope()
            expect("")

        def __dls__brc_lp(kind):
            expect("tkSTR")

        def __dls__dls(kind):
            expect("tkSTR")

        def __dls__str(kind):
            expect("tkDCMA", "tkBRC_RP")

        def __dls__dcma(kind):
            expect("tkSTR", "tkDLS")

        def __dls__brc_rp(kind):
            popscope()
            if SCOPE[-1] == "tkOPTS":
                expect("tkFVAL", "tkBRC_RP")
            else:
                if SCOPE[-1] == "tkKYW" and "tkBRC_LB" in SCOPE:
                    # popscope()
                    expect("tkDPPE", "tkBRC_RB")
                else:
                    expect("", "tkDPPE", "tkBRC_RB")

        def __opts__fopt(kind):
            if branch[-2]["line"] == line:
                print("err: Option on same line (nth)")
            expect("tkFVAL", "tkSTR", "tkDLS")

        def __opts__dls(kind):
            addscope("tkDLS") # Build cmd-string.
            expect("tkBRC_LP")

        def __opts__fval(kind):
            expect("tkFOPT", "tkBRC_RP")

        def __opts__str(kind):
            expect("tkFOPT", "tkBRC_RP")

        def __opts__brc_rp(kind):
            popscope()
            expect("", "tkBRC_RB")

        def __brc_lb__flg(kind):
            addscope(kind)
            # Need the ""?
            # expect("", "tkASG", "tkQMK", "tkDCLN",
            expect("tkASG", "tkQMK", "tkDCLN",
                "tkFVAL", "tkDPPE", "tkBRC_RB")

        def __brc_lb__kyw(kind):
            addscope(kind)
            expect("tkSTR", "tkDLS", "tkBRC_RB")

        def __kyw__str(kind):
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
            # Need the ""?
            # expect("", "tkASG", "tkQMK",
            expect("tkASG", "tkQMK",
                "tkDCLN", "tkFVAL", "tkDPPE")

        def __kyw__kyw(kind):
            addscope(kind)
            expect("tkSTR", "tkDLS") #######

        def __kyw__dppe(kind):
            expect("tkFLG", "tkKYW")

        def __dcma__cmd(kind):
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
                "tkKYW": __brc_lb__kyw
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

        AST = []
        ttid = 0
        ttids = []
        NEXT = []
        SCOPE = []
        branch = []

        i = 0
        l = len(tokens)

        while i < l:
            token = tokens[i]
            kind = token["kind"]
            line = token["line"]
            start = token["start"]
            end = token["end"]
            tid = token["tid"]

            if kind == "tkNL":
                i += 1
                continue

            if kind != "tkEOP":
                ttid = i
                ttids.append(i)

            if kind == "tkTRM":
                addtoken(ttid)

                if not SCOPE:
                    addbranch(branch)
                    newbranch()
                    expect("")

                    # # If branches exist on the same line,
                    # # ensure lines are properly terminated.
                    # if AST and AST[-1][-1]["kind"] not in ("tkTRM", "tkEOP"):
                    #     if AST[-1][-1]["line"] == line:
                    #         err(ttid, "<parent>", "- Improper termination")

                else:
                    if NEXT and NEXT[0] != "":
                        err(ttid, "<child>", "- Improper termination")

                i += 1
                continue

            if not SCOPE:

                addtoken(ttid)

                if kind == "tkSTN":
                    addscope(kind)
                    addbranch(branch)
                    expect("", "tkASG")

                elif kind == "tkVAR":
                    addscope(kind)
                    addbranch(branch)
                    expect("", "tkASG")

                elif kind == "tkCMD":
                    addscope(kind)
                    addbranch(branch)
                    expect("", "tkDDOT", "tkASG", "tkDCMA")

                elif kind == "tkCMT":
                    addbranch(branch)
                    newbranch()
                    expect("")

                elif kind != "tkEOP":
                    message = "\n\n\033[1mToken\033[0m: " + kind + " = "
                    message += json.dumps(token, indent = 2).replace('"', "")
                    err(ttid, "<parent>", message)

            else:

                if kind == "tkCMT":
                    addtoken(ttid)
                    i += 1
                    continue

                # Remove/add necessary tokens when parsing long flag form.
                if "tkBRC_LB" in SCOPE:
                    if "tkDPPE" in NEXT:
                        NEXT.remove("tkDPPE")
                        NEXT.append("tkFLG")
                        NEXT.append("tkKYW")
                        NEXT.append("tkBRC_RB")

                if NEXT and kind not in NEXT:
                    if NEXT[0] == "":
                        clearscope()
                        newbranch()
                        continue

                    else:
                        if kind == "tkEOP":
                            token = tokens[ttid]
                            kind = token["kind"]

                        message = "\n\n\033[1mToken\033[0m: " + kind + " = "
                        message += json.dumps(token, indent = 2).replace('"', "")
                        message += "\n\n\033[1mExpected\033[0m: "
                        for n in NEXT:
                            if not n: n = "\"\""
                            message += "\n - " + n
                        message += "\n\n\033[1mScopes\033[0m: "
                        for s in SCOPE:
                            message += "\n - " + s
                        err(ttid, "<child>", message)

                addtoken(ttid)

                DISPATCH[SCOPE[-1]][kind](kind)

            i += 1

        print("DONE")

        print("\nAST", len(AST), "\n")
        for branch in AST:
            output = ""
            tids = []
            for token in branch:
                start = token["start"]
                end = token["end"]
                tid = token["tid"]
                output += text[start:end + 1]
                tids.append(tid)
                # print(token)

            # print("[tids]", tids)
            print("[LEAF] <" + output + ">")

            print("")

main()
