#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys

from lexer import tokenizer, LINESTARTS
# from pathlib import Path  # [https://stackoverflow.com/a/66195538]

C_LF = 'f'
C_LT = 't'

C_ATSIGN = '@'

C_PRIM_TBOOL = "true"
C_PRIM_FBOOL = "false"

def main():
    if __name__ == "__main__":

        # hdir = str(Path.home())
        # f = open(hdir + "/.nodecliac/registry/nodecliac/nodecliac.acmap", "r")
        # text = f.read()

        f = open("../../../resources/packages/nodecliac/nodecliac.acmap", "r")
        text = f.read()

        text = """@setting =
                                 "123";
        @setting = = "123"
        """

        tokens = tokenizer(text)

        construct = ""
        branch = None
        parent = None
        maxtcount = 0
        maxpathways = 0

        tcount = 0
        lastvalidpath = -1
        pathways = None
        PATHWAYS = {
            "tkSTN": [
                ["tkTRM"],
                ["tkASG", "tkSTR", "tkTRM"],
                ["tkASG", "tkCMD", "tkTRM"]
            ]
        }
        SINGLES = {"tkSTN"}

        AST = []

        def err(line, index, errname):
            sys.exit(f"\033[1mdep.acmap:{line}:{index - LINESTARTS[line]}:\033[0m \033[31;1merror:\033[0m {errname}")

        def validtoken(token):
            kind = token["kind"]
            start = token["start"]
            end = token["end"]
            line = token["line"]

            if kind == "tkSTN":
                if end - start == 0:
                    return (False, line, start, "SIGIL_SETTING_ONLY")

                for i in range(start, end + 1):
                    c = text[i]
                    if i == start:
                        if c != C_ATSIGN:
                            return (False, line, i, "INVALID_SETTING_SIGIL")
                    elif i == start + 1:
                        if not c.isalpha():
                            return (False, line, i, "INVALID_SETTING_IDENT_CHAR")
                    else:
                        if not c.isalnum():
                            return (False, line, i, "INVALID_SETTING_CHAR")

            return (True, line, -1, "")

        def validpathway():
            nonlocal tcount, lastvalidpath

            # Loop over token kinds at construct token count index.
            valid = False

            for j in maxpathways:
                pathway = pathways[j]
                if tcount >= len(pathway): continue
                if kind == pathways[j][tcount]:
                    valid = True
                    lastvalidpath = tcount
                    break

            # When nothing matches, it's the parent token, and
            # the token kind is an allowed single consider it valid.
            if tcount == 0 and lastvalidpath == -1 and kind in SINGLES:
                lastvalidpath = 0

            tcount += 1

            return valid

        i = 0
        l = len(tokens)
        while i < l:
            token = tokens[i]
            kind = token["kind"]
            start = token["start"]
            end = token["end"]
            line = token["line"]
            if kind == "tkNL":
                i += 1
                continue

            # print("L: " + str(line) + ", K: [" + kind + "] V: [" +
            #       text[start:end + 1] + "] ["+str(start), ", " +
            #       str(end) + "]")

            # ---------------------------------------------------------- SETTING
            # @setting = true
            #         | |    ^-EOL-Whitespace-Boundary 3.
            #         ^-^-Whitespace-Boundary 1/2.
            # ^-Sigil.
            #  ^-Name.
            #          ^-Assignment.
            #            ^-Value.
            #
            # ------------------------------------------- SETTING-PARSE-PATHWAYS
            #
            # / 1 / ------------------------------------------------------------
            #
            # @setting _ ;
            # ["tkSTN", "tkTRM"]
            #
            # / 2 / ------------------------------------------------------------
            #
            # @setting _ = _ "" _ ;
            # ["tkSTN", "tkASG", "tkSTR", "tkTRM"]
            #
            # ------------------------------------------------------------------

            if not construct:
                construct = kind
                tcount = 0
                pathways = PATHWAYS.get(construct, [])
                maxpathways = range(len(pathways))

                if not pathways:
                    err(line, start, "INVALID_PATHWAY_PARENT")

                for pathway in pathways:
                    if len(pathway) > maxtcount:
                        maxtcount = len(pathway)

                branch = []
                parent = token
                AST.append(branch)

                i -= 1
            else:
                if construct == "tkSTN":
                    if not len(branch):
                        (valid, *errinfo) = validtoken(token)
                        if valid: branch.append(token)
                        else: err(*errinfo)
                    else:
                        if validpathway():
                            (valid, *errinfo) = validtoken(token)
                            if valid: branch.append(token)
                            else: err(*errinfo)
                        else:
                            tcount = maxtcount
                            if lastvalidpath > -1: i -= 1
                            else: err(line, start, "INVALID_PATHWAY_CHILD")

                        if tcount >= maxtcount: # Variable reset.
                            construct = ""
                            lastvalidpath = -1
                            tcount = 0
                            branch = None
                            parent = None
                            pathways = None
                            maxpathways = None

            i += 1

        print("AST", len(AST))
        # print(AST)
        for b in AST:
            print(b)

main()
