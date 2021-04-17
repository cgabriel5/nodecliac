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

        tokens = tokenizer(text)

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
        tid = 0
        tids = []
        BRACE_CMD = 0

        i = 0
        l = len(tokens)

        while i < l:
            token = tokens[i]
            kind = token["kind"]
            line = token["line"]
            start = token["start"]
            end = token["end"]

            if kind == "tkNL":
                i += 1
                continue

            if kind != "tkEOP":
                tid = i
                tids.append(i)

            if not construct and kind != "tkEOP":
                construct = kind
                branch = []
                AST.append(branch)

                i -= 1

            else:
                if construct == "tkSTN":
                    if not branch:
                        branch.append(token)
                    else:
                        if len(branch) == 1:
                            if kind == "tkASG":
                                branch.append(token)
                            else:
                                reset()
                                i -= 1
                        elif len(branch) == 2:
                            if kind in ("tkSTR", "tkCMD"):
                                branch.append(token)
                                reset()
                            else:
                                err(tid, "[DANGLING] SETTING")

                elif construct == "tkASG":
                    if len(AST) <= 1:
                        err(tid, "INVALID_EMPTY_ASSIGNMENT")
                    else:
                        if AST[-2][0]["kind"] not in ("tkSTN", "tkVAR", "tkCMD"):
                            err(tid, "INVALID_ILLEGAL_ASSIGNMENT_USE")

                    branch.append(token)
                    reset()
                    prevmerge()

                elif construct == "tkVAR":
                    if not branch:
                        branch.append(token)
                    else:
                        if len(branch) == 1:
                            if kind == "tkASG":
                                branch.append(token)
                            else:
                                reset()
                                i -= 1
                        elif len(branch) == 2:
                            if kind in ("tkSTR", "tkCMD"):
                                branch.append(token)
                                reset()
                            else:
                                err(tid, "[DANGLING] VARIABLE")

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
                                err(tid, "INVALID_TRAILING_POST_CMD_TOKEN")
                            reset()
                            continue
                        elif kind == lkind:
                            if lkind == "tkCMD":
                                reset()
                                continue
                            else: err(tid, "INVALID_SUBSEQUENT_CMD_TOKEN")

                        if kind == "tkBRC_LC" :
                            if not BRACE_CMD: BRACE_CMD = tid
                            else: err(tid, "INVALID_LBRACE_CMD_TOKEN")
                        elif kind == "tkBRC_RC":
                            if BRACE_CMD: BRACE_CMD = 0
                            else: err(tid, "INVALID_RBRACE_CMD_TOKEN")

                        if kind == "tkDCMA" and lkind == "tkBRC_LC":
                            err(tid, "INVALID_EMPTY_DCOMMA_CMD_TOKEN")
                        elif kind == "tkBRC_RC" and lkind == "tkDCMA":
                            err(tids[-2], "INVALID_TRAILING_DCOMMA_CMD_TOKEN")
                        elif kind == "tkBRC_RC" and lkind == "tkBRC_LC":
                            err(tids[-2], "INVALID_EMPTY_GROUP_CMD_TOKEN")
                        elif kind == "tkBRC_LC" and lkind != "tkDDOT":
                            err(tid, "INVALID_STARTBRACE_CMD_TOKEN")
                        elif kind == "tkCMD" and lkind == "tkBRC_RC":
                            err(tid, "INVALID_POSTBRACE_CMD_TOKEN")
                        elif kind == "tkDCMA" and not BRACE_CMD:
                            err(tid, "INVALID_COMMA_DEL_CMD_TOKEN")

                        branch.append(token)

                elif construct == "tkASG":
                    branch.append(token)
                    reset()

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
