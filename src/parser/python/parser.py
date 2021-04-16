#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys

from lexer import tokenizer, LINESTARTS
# from pathlib import Path  # [https://stackoverflow.com/a/66195538]

C_LF = 'f'
C_LT = 't'

C_ATSIGN = '@'
C_DOLLARSIGN = '$'

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

        last_true_token = 0
        token = None
        construct = ""
        branch = None
        parent = None
        maxtcount = 0
        maxpathways = 0

        tcount = 0
        lastvalidpathindex = -1
        lastvalidpathway = []
        pathways = None
        PATHWAYS = {
            "tkSTN": [
                ["tkASG", "tkSTR"],
                ["tkASG", "tkCMD"]
            ],
            "tkVAR": [["tkASG", "tkSTR"]],
            # Allowed command tokens (unordered).
            "tkCMD": [["tkCMD", "tkDDOT", "tkBRC_LC", "tkDCMA", "tkBRC_RC"]],
            "tkTRM": []
        }
        SINGLES = {"tkSTN"}

        BRACE_CMD = None

        AST = []

        def err(line, index, errname):
            sys.exit(f"\033[1mdep.acmap:{line}:{index - LINESTARTS[line]}:\033[0m \033[31;1merror:\033[0m {errname}")

        def validtoken(token):
            kind = token["kind"]
            start = token["start"]
            end = token["end"]
            line = token["line"]

            if construct == "tkSTN":
                if tcount == 0:
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
                if tcount == 2 and kind == "tkCMD":
                    if end - start != 3:
                        return (False, line, start, "INVALID_SETTING_UNQT_VAL1")

                    if text[start] not in (C_LF, C_LT):
                        return (False, line, start, "INVALID_SETTING_UNQT_VAL2")

                    value = C_PRIM_TBOOL if text[start] == C_LT else C_PRIM_FBOOL

                    for i in range(start, end + 1):
                        if text[i] != value[i - start]:
                            return (False, line, i, "INVALID_SETTING_UNQT_VAL3")

            elif construct == "tkVAR":
                if tcount == 0:
                    if end - start == 0:
                        return (False, line, start, "SIGIL_VARIABLE_ONLY")

                    for i in range(start, end + 1):
                        c = text[i]
                        if i == start:
                            if c != C_DOLLARSIGN:
                                return (False, line, i, "INVALID_VARIABLE_SIGIL")
                        elif i == start + 1:
                            if not c.isalpha():
                                return (False, line, i, "INVALID_VARIABLE_IDENT_CHAR")
                        else:
                            if not c.isalnum():
                                return (False, line, i, "INVALID_VARIABLE_CHAR")

            elif construct == "tkCMD":
                if not branch:
                    if kind != "tkCMD":
                        return (False, line, start, "INVALID_START_CMD_TOKEN")
                else:
                    # + Subsequent/empty dot/comma delimiter checks.
                    # + Trailing dot/commas.
                    # + Balanced brace checks.
                    # + Proper brace group syntax.
                    # + Empty command groups check.

                    nonlocal BRACE_CMD
                    ltoken = branch[-1]
                    lkind = ltoken["kind"]

                    if kind == lkind:
                        return (False, line, start, "INVALID_SUBSEQUENT_CMD_TOKEN")

                    if kind == "tkBRC_LC" :
                        if not BRACE_CMD: BRACE_CMD = token
                        else: return (False, line, start, "INVALID_LBRACE_CMD_TOKEN")
                    elif kind == "tkBRC_RC":
                        if BRACE_CMD: BRACE_CMD = None
                        else: return (False, line, start, "INVALID_RBRACE_CMD_TOKEN")

                    if kind == "tkDCMA" and lkind == "tkBRC_LC":
                        return (False, token["line"], token["start"], "INVALID_EMPTY_DCOMMA_CMD_TOKEN")

                    elif kind == "tkBRC_RC" and lkind == "tkDCMA":
                        return (False, ltoken["line"], ltoken["start"], "INVALID_TRAILING_DCOMMA_CMD_TOKEN")

                    elif kind == "tkBRC_RC" and lkind == "tkBRC_LC":
                        return (False, ltoken["line"], ltoken["start"], "INVALID_EMPTY_GROUP_CMD_TOKEN")

                    elif kind == "tkBRC_LC" and lkind != "tkDDOT":
                        return (False, line, start, "INVALID_STARTBRACE_CMD_TOKEN")

                    elif kind == "tkCMD" and lkind == "tkBRC_RC":
                        return (False, line, start, "INVALID_POSTBRACE_CMD_TOKEN")

                    elif kind == "tkDCMA" and not BRACE_CMD:
                        return (False, line, start, "INVALID_COMMA_DEL_CMD_TOKEN")

            return (True, line, -1, "")

        def validpathway():
            if kind == "tkCMT": return True

            nonlocal tcount, lastvalidpathindex, lastvalidpathway

            # Loop over token kinds at construct token count index.
            valid = False

            if construct != "tkCMD":
                for j in maxpathways:
                    pathway = pathways[j]
                    if tcount >= len(pathway): continue
                    if kind == pathways[j][tcount]:
                        valid = True
                        lastvalidpathway = pathways[j]
                        lastvalidpathindex = tcount
                        break

                # When nothing matches, it's the parent token, and
                # the token kind is an allowed single consider it valid.
                if tcount == 0 and lastvalidpathindex == -1:
                    lastvalidpathindex = 0
                    if kind == "tkEOP" and branch[0]["kind"] not in SINGLES:
                        lastvalidpathindex = -1

                tcount += 1

            else:
                valid = kind in pathways[0]
                if (kind == "tkCMD" and branch[-1]["kind"] != "tkDDOT"
                    and not BRACE_CMD):
                    valid = False
                if not valid: lastvalidpathindex = 0

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
            elif kind not in ("tkEOP", "tkCMT"):
                last_true_token = i

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
                if kind != "tkEOP":
                    # Check if previous branch was properly terminated.
                    if AST and kind != "tkTRM":
                        ltoken = AST[-1][-1] # Last branch token.
                        lkind = ltoken["kind"]
                        lline = ltoken.get("line_end", ltoken["line"])
                        if lline == token["line"] and lkind != "tkTRM":
                            err(line, ltoken["end"], "UNTERMINATED_BRANCH")

                    # Add ';' previous branch if not already terminated.
                    if kind == "tkTRM":
                        if AST and AST[-1][-1]["kind"] != "tkTRM":
                            AST[-1].append(token)
                        i += 1
                        continue

                    if kind == "tkCMT":
                        i += 1
                        continue

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
                if construct in ("tkSTN", "tkVAR", "tkCMD"):
                    if not len(branch):
                        (valid, *errinfo) = validtoken(token)
                        if valid: branch.append(token)
                        else: err(*errinfo)
                    else:
                        if validpathway():
                            if kind == "tkEOP":
                                if construct == "tkCMD":
                                    if BRACE_CMD:
                                        err(BRACE_CMD["line"], BRACE_CMD["start"], "INVALID_UNCLOSED_LBRACE_CMD_TOKEN")
                                    if branch[-1]["kind"] == "tkDDOT":
                                        err(branch[-1]["line"], branch[-1]["start"], "INVALID_TRAILING_POST_CMD_TOKEN")

                            if kind != "tkCMT":
                                (valid, *errinfo) = validtoken(token)
                                if valid: branch.append(token)
                                else: err(*errinfo)
                        else:
                            tcount = maxtcount
                            if lastvalidpathindex > -1: i -= 1
                            else:
                                ttoken = tokens[last_true_token]
                                err(ttoken["line"], ttoken["end"], "INVALID_PATHWAY_CHILD")

                        if tcount >= maxtcount: # Variable reset.

                            if (len(lastvalidpathway)) - (len(branch) - 1) > 1 and len(branch) != 1:
                                ttoken = tokens[last_true_token]
                                err(ttoken["line"], ttoken["start"], "UNFINISHED_PATHWAY")

                            construct = ""
                            lastvalidpathindex = -1
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
