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

        text = """
        @setting = "123"
        @setting
= 12

$var = 12

a.{b,c,d}.a =


nnn
        """

        text = """
@setting
= 90

a

b.c.d

        """

# a.{b,c,d}.a

        (tokens, ttypes) = tokenizer(text)

        # def err(line, index, errname):
        def err(tid, errname):
            token = tokens[tid]
            line = token["line"]
            index = token["start"]

            sys.exit(f"\033[1mdep.acmap:{line}:{index - LINESTARTS[line]}:\033[0m \033[31;1merror:\033[0m {errname}")

        def reset():
            nonlocal construct, branch
            construct = ""
            branch = None

        def prevmerge():
            ltoken = AST.pop()
            for tkn in ltoken:
                AST[-1].append(tkn)

        AST = []
        construct = ""
        branch = None
        ttid = 0
        ttids = []
        BRACE_CMD = 0

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

            if not construct and kind != "tkEOP":
                construct = kind
                branch = []
                AST.append(branch)

                i -= 1

            else:
                if construct == "tkSTN":
                    branch.append(token)
                    reset()

                elif construct == "tkASG":
                    if len(AST) <= 1:
                        err(ttid, "INVALID_EMPTY_ASSIGNMENT")
                    else:
                        lparent = AST[-2][0]
                        lpkind = lparent["kind"]
                        if lpkind not in ("tkSTN", "tkVAR", "tkCMD"):
                            err(ttid, "INVALID_ILLEGAL_ASSIGNMENT_USE")

                        nkind = ttypes.get(i + 1, None)
                        if lpkind in ("tkSTN", "tkVAR"):
                            # if not nkind:
                                # err(ttid, "INCOMPLETE_TOKEN_" + kind)
                            if nkind not in ("tkSTR", "tkCMD"):
                                err(ttid, "INCOMPLETE_TOKEN_2_" + kind)

                            # Tokenization is mostly context-free so improve
                            # token context for further pipeline work.
                            if nkind == "tkCMD":
                                ttypes[i + 1] = "tkBOL"
                                tokens[i + 1]["kind"] = "tkBOL"

                    branch.append(token)
                    reset()
                    prevmerge()

                elif construct == "tkBOL":
                    branch.append(token)
                    reset()
                    prevmerge()

                elif construct == "tkSTR":
                    if len(AST) <= 1:
                        err(ttid, "INVALID_EMPTY_STR_TOKEN")

                    lbranch = AST[-2]
                    lparent = lbranch[0]
                    lpkind = lparent["kind"]

                    if lpkind in ("tkSTN", "tkVAR"):
                        if len(lbranch) != 2:
                            err(ttid, "INVALID_STR_TOKEN")
                    else:
                        err(ttid, "INVALID_UNEXPECTED_STR_TOKEN")

                    branch.append(token)
                    reset()
                    prevmerge()

                elif construct == "tkVAR":
                    branch.append(token)
                    reset()

                elif construct == "tkCMD":
                    if not branch:
                        branch.append(token)
                    else:
                        ltoken = branch[-1]
                        lkind = ltoken["kind"]

                        if kind not in ["tkCMD", "tkDDOT", "tkBRC_LC", "tkDCMA", "tkBRC_RC"]:
                            if BRACE_CMD:
                                err(BRACE_CMD, "INVALID_UNCLOSED_LBRACE_CMD_TOKEN")
                            elif branch[-1]["kind"] == "tkDDOT":
                                err(ttid, "INVALID_TRAILING_POST_CMD_TOKEN")
                            reset()
                            continue
                        elif kind == lkind:
                            if lkind == "tkCMD":
                                reset()
                                continue
                            else: err(ttid, "INVALID_SUBSEQUENT_CMD_TOKEN")

                        if kind == "tkBRC_LC" :
                            if not BRACE_CMD: BRACE_CMD = ttid
                            else: err(ttid, "INVALID_LBRACE_CMD_TOKEN")
                        elif kind == "tkBRC_RC":
                            if BRACE_CMD: BRACE_CMD = 0
                            else: err(ttid, "INVALID_RBRACE_CMD_TOKEN")

                        if kind == "tkDCMA" and lkind == "tkBRC_LC":
                            err(ttid, "INVALID_EMPTY_DCOMMA_CMD_TOKEN")
                        elif kind == "tkBRC_RC" and lkind == "tkDCMA":
                            err(ttids[-2], "INVALID_TRAILING_DCOMMA_CMD_TOKEN")
                        elif kind == "tkBRC_RC" and lkind == "tkBRC_LC":
                            err(ttids[-2], "INVALID_EMPTY_GROUP_CMD_TOKEN")
                        elif kind == "tkBRC_LC" and lkind != "tkDDOT":
                            err(ttid, "INVALID_STARTBRACE_CMD_TOKEN")
                        elif kind == "tkCMD" and lkind == "tkBRC_RC":
                            err(ttid, "INVALID_POSTBRACE_CMD_TOKEN")
                        elif kind == "tkDCMA" and not BRACE_CMD:
                            err(ttid, "INVALID_COMMA_DEL_CMD_TOKEN")

                        branch.append(token)

                elif construct == "tkASG":
                    branch.append(token)
                    reset()

                else:
                    if kind != "tkEOP":
                        err(ttid, "UNEXPECTED_TOKEN_" + kind)

            i += 1

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
                print(token)

            print("[tids]", tids)
            print("[LEAF] [" + output + "]")

            print("")

main()
