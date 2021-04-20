#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys

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

        def err(tid, errname):
            token = tokens[tid]
            line = token["line"]
            index = token["start"]

            sys.exit("\033[1mdep.acmap:" +
                    f"{line}:{index - LINESTARTS[line]}:" +
                    f"\033[0m \033[31;1merror:\033[0m {errname}")

        AST = []
        ttid = 0
        ttids = []
        NEXT = []
        SCOPE = []
        branch = []

        def completing(kind):
            return SCOPE[-1] == kind

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
                    SCOPE.append(kind)

                    branch.append(token)
                    AST.append(branch)
                    NEXT = ["", "tkASG"]

                elif kind == "tkVAR":
                    SCOPE.append(kind)

                    branch.append(token)
                    AST.append(branch)
                    NEXT = ["", "tkASG"]

                elif kind == "tkCMD":
                    SCOPE.append(kind)

                    branch.append(token)
                    AST.append(branch)
                    NEXT = ["", "tkDDOT", "tkASG"]

                elif kind != "tkEOP":
                    err(ttid, "INVALID_PATHWAY_CONSTRUCT_" + kind
                        + " E: " + str(NEXT) + " , G: "+ kind)

            else:

                if NEXT and kind not in NEXT:
                    if NEXT[0] == "":
                        SCOPE.clear()
                        branch = []
                        continue
                    else:
                        if kind == "tkEOP":
                            token = tokens[ttid]
                            kind = token["kind"]

                        err(ttid, "INVALID_PATHWAY_CHILD_" + kind
                            + " E: " + str(NEXT) + " , G: "+ kind)

                if kind == "tkASG":
                    if completing("tkSTN"):
                        branch.append(token)
                        NEXT = ["tkSTR", "tkAVAL"]

                    elif completing("tkVAR"):
                        branch.append(token)
                        NEXT = ["tkSTR"]

                elif kind == "tkSTR":
                    if completing("tkSTN"):
                        branch.append(token)
                        SCOPE.clear()
                        branch = []

                    elif completing("tkVAR"):
                        branch.append(token)
                        SCOPE.clear()
                        branch = []

                elif kind == "tkAVAL":
                    if completing("tkSTN"):
                        branch.append(token)
                        SCOPE.clear()
                        branch = []

                elif kind == "tkDDOT":
                    if completing("tkCMD"):
                        branch.append(token)
                        NEXT = ["tkCMD", "tkBRC_LC"]

                elif kind == "tkCMD":
                    if completing("tkCMD"):
                        branch.append(token)
                        NEXT = ["", "tkDDOT"]

                    elif completing("tkBRC_LC"):
                        branch.append(token)
                        NEXT = ["tkDCMA", "tkBRC_RC"]

                elif kind == "tkBRC_LC":
                    if completing("tkCMD"):
                        branch.append(token)
                        SCOPE.append(kind)
                        NEXT = ["tkCMD"]

                elif kind == "tkDCMA":
                    if completing("tkBRC_LC"):
                        branch.append(token)
                        NEXT.clear()
                        NEXT = ["tkCMD"]

                elif kind == "tkBRC_RC":
                    if completing("tkBRC_LC"):
                        branch.append(token)
                        SCOPE.pop()
                        NEXT = ["", "tkDDOT"]

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
            print("[LEAF] [" + output + "]")

            print("")

main()
