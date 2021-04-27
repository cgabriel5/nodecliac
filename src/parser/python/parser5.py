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

                if completing("tkSTN"):

                    if kind == "tkASG":
                        addtoken(ttid)
                        expect("tkSTR", "tkAVAL")

                    elif kind in ("tkSTR", "tkAVAL"):
                        addtoken(ttid)
                        clearscope()
                        newbranch()

                elif completing("tkVAR"):

                    if kind == "tkASG":
                        addtoken(ttid)
                        expect("tkSTR")

                    elif kind == "tkSTR":
                        addtoken(ttid)
                        clearscope()
                        newbranch()

                elif completing("tkCMD"):

                    if kind == "tkASG":
                        addtoken(ttid)
                        expect("tkBRC_LB", "tkFLG", "tkKYW")

                    elif kind == "tkBRC_LB":
                        addtoken(ttid)
                        addscope(kind)
                        expect("tkFLG", "tkKYW")

                    elif kind == "tkBRC_RB":
                        addtoken(ttid)
                        expect("", "tkCMD")

                    elif kind == "tkFLG":
                        addtoken(ttid)
                        addscope(kind)
                        expect("", "tkASG", "tkQMK", "tkDCLN", "tkFVAL", "tkDPPE", "tkBRC_RB")

                    elif kind == "tkKYW":
                        addtoken(ttid)
                        addscope(kind)
                        expect("tkSTR")

                    elif kind == "tkDDOT":
                        addtoken(ttid)
                        expect("tkCMD", "tkBRC_LC")

                    elif kind == "tkCMD":
                        addtoken(ttid)
                        expect("", "tkDDOT", "tkASG")

                    elif kind == "tkBRC_LC":
                        addtoken(ttid)
                        addscope(kind)
                        expect("tkCMD")

                    elif kind == "tkDCMA":
                        addtoken(ttid)
                        addscope(kind)
                        # clearscope()
                        # newbranch()
                        expect("tkCMD")
                        # NEXT.clear()

                elif completing("tkFLG"):

                    if kind == "tkASG":
                        addtoken(ttid)
                        expect("", "tkMTL", "tkDPPE", "tkBRC_LP", "tkFVAL", "tkSTR", "tkDLS", "tkBRC_RB")

                    elif kind == "tkBRC_RB":
                        addtoken(ttid)
                        popscope()
                        expect("")

                    elif kind == "tkDLS":
                        addtoken(ttid)
                        addscope(kind) # Build cmd-string.
                        expect("tkBRC_LP")

                    elif kind == "tkFLG":
                        addtoken(ttid)
                        # addscope(kind)
                        expect("", "tkASG", "tkQMK", "tkDCLN", "tkFVAL", "tkDPPE")

                    elif kind == "tkKYW":
                        addtoken(ttid)
                        addscope(kind)
                        expect("tkSTR")

                    elif kind == "tkBRC_LP":
                        addtoken(ttid)
                        addscope(kind)
                        expect("tkFVAL", "tkSTR", "tkFOPT")

                    elif kind == "tkFVAL":
                        addtoken(ttid)
                        expect("", "tkDPPE")

                    elif kind == "tkQMK":
                        addtoken(ttid)
                        expect("", "tkDPPE")

                    elif kind == "tkDCLN":

                        if branch[-1]["kind"] != "tkDCLN":
                            addtoken(ttid)
                            expect("tkDCLN")

                        else:
                            addtoken(ttid)
                            expect("", "tkFLGA")

                    elif kind == "tkFLGA":
                        addtoken(ttid)
                        expect("", "tkASG", "tkQMK", "tkDPPE")

                    elif kind == "tkMTL":
                        addtoken(ttid)
                        expect("", "tkBRC_LP", "tkDPPE")

                    elif kind == "tkDPPE":
                        addtoken(ttid)
                        expect("tkFLG")

                    elif kind == "tkSTR":
                        addtoken(ttid)
                        expect("", "tkDPPE")

                elif completing("tkBRC_LP"):

                    if kind == "tkBRC_RB":
                        addtoken(ttid)
                        popscope()
                        expect("")

                    elif kind == "tkFOPT":
                        # addtoken(ttid)
                        # [TODO] Make this code robust.
                        if branch[-1]["kind"] == "tkBRC_LP":
                            addscope("tkOPTS")
                            expect("tkFVAL", "tkSTR", "tkDLS")
                        addtoken(ttid)

                    elif kind == "tkBRC_RP":
                        addtoken(ttid)
                        popscope()
                        expect("", "tkDPPE")

                    elif kind == "tkFVAL":
                        addtoken(ttid)
                        expect("tkFVAL", "tkSTR", "tkBRC_RP")

                    elif kind == "tkSTR":
                        addtoken(ttid)
                        expect("tkFVAL", "tkSTR", "tkBRC_RP")

                    elif kind == "tkDCMA":
                        addtoken(ttid)
                        expect("tkFVAL", "tkSTR")

                elif completing("tkDLS"):

                    if kind == "tkDLS":
                        addtoken(ttid)
                        # addscope(kind) # Build cmd-string.
                        expect("tkSTR")

                    elif kind == "tkBRC_LP":
                        addtoken(ttid)
                        expect("tkSTR")

                    elif kind == "tkBRC_RP":
                        addtoken(ttid)
                        popscope()
                        if SCOPE[-1] == "tkOPTS":
                            expect("tkFVAL", "tkBRC_RP")
                        else:
                            expect("", "tkDPPE")

                    elif kind == "tkSTR":
                        addtoken(ttid)
                        expect("tkDCMA", "tkBRC_RP")

                    elif kind == "tkDCMA":
                        addtoken(ttid)
                        expect("tkSTR", "tkDLS")

                elif completing("tkOPTS"):

                    if kind == "tkDLS":
                        addtoken(ttid)
                        addscope("tkDLS") # Build cmd-string.
                        expect("tkBRC_LP")

                    elif kind == "tkFOPT":
                        addtoken(ttid)
                        expect("tkFVAL", "tkSTR", "tkDLS")

                    elif kind == "tkBRC_RP":
                        addtoken(ttid)
                        popscope()
                        expect("", "tkBRC_RB")

                    elif kind == "tkFVAL":
                        addtoken(ttid)
                        expect("tkFOPT", "tkBRC_RP")

                    elif kind == "tkSTR":
                        addtoken(ttid)
                        expect("tkFOPT", "tkBRC_RP")

                elif completing("tkBRC_LB"):

                    if kind == "tkFLG":
                        addtoken(ttid)
                        addscope(kind)
                        expect("", "tkASG", "tkQMK", "tkDCLN", "tkFVAL", "tkDPPE", "tkBRC_RB")

                    elif kind == "tkKYW":
                        addtoken(ttid)
                        addscope(kind)
                        expect("tkSTR")

                elif completing("tkKYW"):

                    if kind == "tkSTR":
                        addtoken(ttid)
                        popscope()
                        addscope("tkFLG") # Re-use flag pathways for now.
                        expect("", "tkDPPE")

                elif completing("tkBRC_LC"):

                    if kind == "tkCMD":
                        addtoken(ttid)
                        expect("tkDCMA", "tkBRC_RC")

                    elif kind == "tkDCMA":
                        addtoken(ttid)
                        expect("tkCMD")

                    elif kind == "tkBRC_RC":
                        addtoken(ttid)
                        popscope()
                        expect("", "tkDDOT", "tkASG")

                elif completing("tkDCMA"):

                    if kind == "tkCMD":
                        addtoken(ttid)
                        popscope()
                        expect("", "tkDDOT", "tkASG", "tkDCMA")

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
