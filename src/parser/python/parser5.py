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
            index = token["start"]

            sys.exit("\033[1mdep.acmap:" +
                    f"{line}:{index - LINESTARTS[line]}:" +
                    f"\033[0m \033[31;1merror:\033[0m <{etype}> {message}")

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

            if not SCOPE:

                if kind == "tkSTN":
                    addscope(kind)
                    addtoken(ttid)
                    addbranch(branch)
                    expect("", "tkASG")

                elif kind == "tkVAR":
                    addscope(kind)
                    addtoken(ttid)
                    addbranch(branch)
                    expect("", "tkASG")

                elif kind == "tkCMD":
                    addscope(kind)
                    addtoken(ttid)
                    addbranch(branch)
                    expect("", "tkDDOT", "tkASG", "tkDCMA")

                elif kind != "tkEOP":
                    message = "\n\n\033[1mGot\033[0m: " + kind
                    message += "\n\n" + json.dumps(token, indent = 2)
                    message += "\n\n\033[1mExpected\033[0m: "
                    for n in NEXT:
                        if not n: n = "\"\""
                        message += "\n    - " + n
                    message += "\n\n\033[1mScopes\033[0m: "
                    for s in SCOPE:
                        message += "\n    - " + s
                    err(ttid, "parent", message)

            else:

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

                        message = "\n\n\033[1mGot\033[0m: " + kind
                        message += "\n\n" + json.dumps(token, indent = 2)
                        message += "\n\n\033[1mExpected\033[0m: "
                        for n in NEXT:
                            if not n: n = "\"\""
                            message += "\n    - " + n
                        message += "\n\n\033[1mScopes\033[0m: "
                        for s in SCOPE:
                            message += "\n    - " + s
                        err(ttid, "child", message)

                if kind == "tkASG":
                    if completing("tkSTN"):
                        addtoken(ttid)
                        expect("tkSTR", "tkAVAL")

                    elif completing("tkVAR"):
                        addtoken(ttid)
                        expect("tkSTR")

                    elif completing("tkCMD"):
                        addtoken(ttid)
                        expect("tkBRC_LB", "tkFLG", "tkKYW")

                    elif completing("tkFLG"):
                        addtoken(ttid)
                        expect("", "tkMTL", "tkDPPE", "tkBRC_LP", "tkFVAL", "tkSTR", "tkDLS", "tkBRC_RB")

                elif kind == "tkBRC_LB":
                    if completing("tkCMD"):
                        addtoken(ttid)
                        addscope(kind)
                        expect("tkFLG", "tkKYW")

                elif kind == "tkBRC_RB":
                    if completing("tkCMD"):
                        addtoken(ttid)
                        expect("", "tkCMD")

                    elif completing("tkFLG"):
                        addtoken(ttid)
                        popscope()
                        expect("")

                    elif completing("tkBRC_LP"):
                        addtoken(ttid)
                        popscope()
                        expect("")

                elif kind == "tkDLS":
                    if completing("tkFLG"):
                        addtoken(ttid)
                        addscope(kind) # Build cmd-string.
                        expect("tkBRC_LP")

                    elif completing("tkDLS"):
                        addtoken(ttid)
                        # addscope(kind) # Build cmd-string.
                        expect("tkSTR")

                    elif completing("tkOPTS"):
                        addtoken(ttid)
                        addscope("tkDLS") # Build cmd-string.
                        expect("tkBRC_LP")

                elif kind == "tkFLG":
                    if completing("tkCMD") or completing("tkBRC_LB"):
                        addtoken(ttid)
                        addscope(kind)
                        expect("", "tkASG", "tkQMK", "tkDCLN", "tkFVAL", "tkDPPE", "tkBRC_RB")
                    elif completing("tkFLG"):
                        addtoken(ttid)
                        # addscope(kind)
                        expect("", "tkASG", "tkQMK", "tkDCLN", "tkFVAL", "tkDPPE")

                elif kind == "tkKYW":
                    if completing("tkCMD"):
                        addtoken(ttid)
                        addscope(kind)
                        expect("tkSTR")

                    elif completing("tkFLG"):
                        addtoken(ttid)
                        addscope(kind)
                        expect("tkSTR")

                    elif completing("tkBRC_LB"):
                        addtoken(ttid)
                        addscope(kind)
                        expect("tkSTR")

                elif kind == "tkBRC_LP":
                    if completing("tkFLG"):
                        addtoken(ttid)
                        addscope(kind)
                        expect("tkFVAL", "tkSTR", "tkFOPT")

                    elif completing("tkDLS"):
                        addtoken(ttid)
                        expect("tkSTR")

                elif kind == "tkFOPT":
                    if completing("tkBRC_LP"):
                        # addtoken(ttid)
                        # [TODO] Make this code robust.
                        if branch[-1]["kind"] == "tkBRC_LP":
                            addscope("tkOPTS")
                            expect("tkFVAL", "tkSTR", "tkDLS")
                        addtoken(ttid)
                    elif completing("tkOPTS"):
                        addtoken(ttid)
                        expect("tkFVAL", "tkSTR", "tkDLS")

                elif kind == "tkBRC_RP":
                    if completing("tkBRC_LP"):
                        addtoken(ttid)
                        popscope()
                        expect("", "tkDPPE")

                    elif completing("tkDLS"):
                        addtoken(ttid)
                        popscope()
                        if SCOPE[-1] == "tkOPTS":
                            expect("tkFVAL", "tkBRC_RP")
                        else:
                            expect("", "tkDPPE")

                    elif completing("tkOPTS"):
                        addtoken(ttid)
                        popscope()
                        expect("", "tkBRC_RB")

                elif kind == "tkFVAL":
                    if completing("tkFLG"):
                        addtoken(ttid)
                        expect("", "tkDPPE")

                    elif completing("tkBRC_LP"):
                        addtoken(ttid)
                        expect("tkFVAL", "tkSTR", "tkBRC_RP")

                    elif completing("tkOPTS"):
                        addtoken(ttid)
                        expect("tkFOPT", "tkBRC_RP")

                elif kind == "tkQMK":
                    if completing("tkFLG"):
                        addtoken(ttid)
                        expect("", "tkDPPE")

                elif kind == "tkDCLN":
                    if completing("tkFLG"):
                        if branch[-1]["kind"] != "tkDCLN":
                            addtoken(ttid)
                            expect("tkDCLN")
                        else:
                            addtoken(ttid)
                            expect("", "tkFLGA")

                elif kind == "tkFLGA":
                    if completing("tkFLG"):
                        addtoken(ttid)
                        expect("", "tkASG", "tkQMK", "tkDPPE")

                elif kind == "tkMTL":
                    if completing("tkFLG"):
                        addtoken(ttid)
                        expect("", "tkBRC_LP", "tkDPPE")

                elif kind == "tkDPPE":
                    if completing("tkFLG"):
                        addtoken(ttid)
                        expect("tkFLG")

                elif kind == "tkSTR":

                    if completing("tkFLG"):
                        addtoken(ttid)
                        expect("", "tkDPPE")

                    elif completing("tkBRC_LP"):
                        addtoken(ttid)
                        expect("tkFVAL", "tkSTR", "tkBRC_RP")

                    elif completing("tkDLS"):
                        addtoken(ttid)
                        expect("tkDCMA", "tkBRC_RP")

                    elif completing("tkKYW"):
                        addtoken(ttid)
                        popscope()
                        addscope("tkFLG") # Re-use flag pathways for now.
                        expect("", "tkDPPE")

                    elif completing("tkSTN"):
                        addtoken(ttid)
                        clearscope()
                        newbranch()

                    elif completing("tkVAR"):
                        addtoken(ttid)
                        clearscope()
                        newbranch()

                    elif completing("tkOPTS"):
                        addtoken(ttid)
                        expect("tkFOPT", "tkBRC_RP")

                elif kind == "tkAVAL":
                    if completing("tkSTN"):
                        addtoken(ttid)
                        clearscope()
                        newbranch()

                elif kind == "tkDDOT":
                    if completing("tkCMD"):
                        addtoken(ttid)
                        expect("tkCMD", "tkBRC_LC")

                elif kind == "tkCMD":
                    if completing("tkCMD"):
                        addtoken(ttid)
                        expect("", "tkDDOT", "tkASG")

                    elif completing("tkBRC_LC"):
                        addtoken(ttid)
                        expect("tkDCMA", "tkBRC_RC")

                    elif completing("tkDCMA"):
                        addtoken(ttid)
                        popscope()
                        expect("", "tkDDOT", "tkASG", "tkDCMA")

                elif kind == "tkBRC_LC":
                    if completing("tkCMD"):
                        addtoken(ttid)
                        addscope(kind)
                        expect("tkCMD")

                elif kind == "tkDCMA":
                    if completing("tkCMD"):
                        addtoken(ttid)
                        addscope(kind)
                        # clearscope()
                        # newbranch()
                        expect("tkCMD")
                        # NEXT.clear()

                    elif completing("tkBRC_LC"):
                        addtoken(ttid)
                        expect("tkCMD")

                    elif completing("tkBRC_LP"):
                        addtoken(ttid)
                        expect("tkFVAL", "tkSTR")

                    elif completing("tkDLS"):
                        addtoken(ttid)
                        expect("tkSTR", "tkDLS")

                elif kind == "tkBRC_RC":
                    if completing("tkBRC_LC"):
                        addtoken(ttid)
                        popscope()
                        expect("", "tkDDOT", "tkASG")

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
