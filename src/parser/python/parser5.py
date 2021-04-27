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

                addtoken(ttid)

                if completing("tkSTN"):

                    if kind == "tkASG":
                        expect("tkSTR", "tkAVAL")

                    elif kind in ("tkSTR", "tkAVAL"):
                        clearscope()
                        newbranch()

                elif completing("tkVAR"):

                    if kind == "tkASG":
                        expect("tkSTR")

                    elif kind == "tkSTR":
                        clearscope()
                        newbranch()

                elif completing("tkCMD"):

                    if kind == "tkASG":
                        expect("tkBRC_LB", "tkFLG", "tkKYW")

                    elif kind == "tkBRC_LB":
                        addscope(kind)
                        expect("tkFLG", "tkKYW")

                    elif kind == "tkBRC_RB":
                        expect("", "tkCMD")

                    elif kind == "tkFLG":
                        addscope(kind)
                        expect("", "tkASG", "tkQMK", "tkDCLN",
                            "tkFVAL", "tkDPPE", "tkBRC_RB")

                    elif kind == "tkKYW":
                        addscope(kind)
                        expect("tkSTR")

                    elif kind == "tkDDOT":
                        expect("tkCMD", "tkBRC_LC")

                    elif kind == "tkCMD":
                        expect("", "tkDDOT", "tkASG")

                    elif kind == "tkBRC_LC":
                        addscope(kind)
                        expect("tkCMD")

                    elif kind == "tkDCMA":
                        addscope(kind)
                        expect("tkCMD")

                elif completing("tkBRC_LC"):

                    if kind == "tkCMD":
                        expect("tkDCMA", "tkBRC_RC")

                    elif kind == "tkDCMA":
                        expect("tkCMD")

                    elif kind == "tkBRC_RC":
                        popscope()
                        expect("", "tkDDOT", "tkASG")

                elif completing("tkFLG"):

                    if kind == "tkDCLN":

                        if branch[-1]["kind"] != "tkDCLN":
                            expect("tkDCLN")

                        else:
                            expect("", "tkFLGA")

                    elif kind == "tkFLGA":
                        expect("", "tkASG", "tkQMK", "tkDPPE")

                    elif kind == "tkQMK":
                        expect("", "tkDPPE")

                    elif kind == "tkASG":
                        expect("", "tkMTL", "tkDPPE", "tkBRC_LP",
                            "tkFVAL", "tkSTR", "tkDLS", "tkBRC_RB")

                    elif kind == "tkMTL":
                        expect("", "tkBRC_LP", "tkDPPE")

                    elif kind == "tkDLS":
                        addscope(kind) # Build cmd-string.
                        expect("tkBRC_LP")

                    elif kind == "tkBRC_LP":
                        addscope(kind)
                        expect("tkFVAL", "tkSTR", "tkFOPT")

                    elif kind == "tkFLG":
                        expect("", "tkASG", "tkQMK",
                            "tkDCLN", "tkFVAL", "tkDPPE")

                    elif kind == "tkKYW":
                        addscope(kind)
                        expect("tkSTR")

                    elif kind == "tkSTR":
                        expect("", "tkDPPE")

                    elif kind == "tkFVAL":
                        expect("", "tkDPPE")

                    elif kind == "tkDPPE":
                        expect("tkFLG")

                    elif kind == "tkBRC_RB":
                        popscope()
                        expect("")

                elif completing("tkBRC_LP"):

                    if kind == "tkFOPT":
                        # [TODO] Make this code robust.
                        if branch[-1]["kind"] == "tkBRC_LP":
                            addscope("tkOPTS")
                            expect("tkFVAL", "tkSTR", "tkDLS")

                    elif kind == "tkFVAL":
                        expect("tkFVAL", "tkSTR", "tkBRC_RP")

                    elif kind == "tkSTR":
                        expect("tkFVAL", "tkSTR", "tkBRC_RP")

                    elif kind == "tkDCMA":
                        expect("tkFVAL", "tkSTR")

                    elif kind == "tkBRC_RP":
                        popscope()
                        expect("", "tkDPPE")

                    elif kind == "tkBRC_RB":
                        popscope()
                        expect("")

                elif completing("tkDLS"):

                    if kind == "tkBRC_LP":
                        expect("tkSTR")

                    elif kind == "tkDLS":
                        expect("tkSTR")

                    elif kind == "tkSTR":
                        expect("tkDCMA", "tkBRC_RP")

                    elif kind == "tkDCMA":
                        expect("tkSTR", "tkDLS")

                    elif kind == "tkBRC_RP":
                        popscope()
                        if SCOPE[-1] == "tkOPTS":
                            expect("tkFVAL", "tkBRC_RP")
                        else:
                            expect("", "tkDPPE")

                elif completing("tkOPTS"):

                    if kind == "tkFOPT":
                        expect("tkFVAL", "tkSTR", "tkDLS")

                    elif kind == "tkDLS":
                        addscope("tkDLS") # Build cmd-string.
                        expect("tkBRC_LP")

                    elif kind == "tkFVAL":
                        expect("tkFOPT", "tkBRC_RP")

                    elif kind == "tkSTR":
                        expect("tkFOPT", "tkBRC_RP")

                    elif kind == "tkBRC_RP":
                        popscope()
                        expect("", "tkBRC_RB")

                elif completing("tkBRC_LB"):

                    if kind == "tkFLG":
                        addscope(kind)
                        expect("", "tkASG", "tkQMK", "tkDCLN",
                            "tkFVAL", "tkDPPE", "tkBRC_RB")

                    elif kind == "tkKYW":
                        addscope(kind)
                        expect("tkSTR")

                elif completing("tkKYW"):

                    if kind == "tkSTR":
                        popscope()
                        addscope("tkFLG") # Re-use flag pathways for now.
                        expect("", "tkDPPE")

                elif completing("tkDCMA"):

                    if kind == "tkCMD":
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
