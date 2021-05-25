#!/usr/bin/env python3
# -*- coding: utf-8 -*-

C_NL = '\n'
C_DOT = '.'
C_TAB = '\t'
C_PIPE = '|'
C_SPACE = ' '
C_QMARK = '?'
C_HYPHEN = '-'
C_ESCAPE = '\\'
C_LPAREN = '('
C_RPAREN = ')'
C_LCURLY = '{'
C_RCURLY = '}'
C_LBRACE = '['
C_RBRACE = ']'
C_ATSIGN = '@'
C_ASTERISK = '*'
C_DOLLARSIGN = '$'
C_UNDERSCORE = '_'

SOT = {  # Start-of-token chars.
    "#": "tkCMT",
    "@": "tkSTN",
    "$": "tkVAR",
    "-": "tkFLG",
    "?": "tkQMK",
    "*": "tkMTL",
    ".": "tkDDOT",
    "\"": "tkSTR",
    "'": "tkSTR",
    "=": "tkASG",
    "|": "tkDPPE",
    ",": "tkDCMA",
    ":": "tkDCLN",
    ";": "tkTRM",
    "(": "tkBRC",
    ")": "tkBRC",
    "[": "tkBRC",
    "]": "tkBRC",
    "{": "tkBRC",
    "}": "tkBRC",
    "\n": "tkNL"
}

BRCTOKENS = {
    C_LPAREN: "tkBRC_LP",
    C_RPAREN: "tkBRC_RP",
    C_LCURLY: "tkBRC_LC",
    C_RCURLY: "tkBRC_RC",
    C_LBRACE: "tkBRC_LB",
    C_RBRACE: "tkBRC_RB"
}

LINESTARTS = {1: -1}

KEYWORDS = ["default", "context", "filedir", "exclude"]
# Invalid command start-of-token chars.
XCSCOPES = [C_ATSIGN, C_DOT, C_LCURLY, C_RCURLY]

def tokenizer(text):
    c = ''
    dtids = {}
    ttids = []
    tokens = []
    ttypes = {}
    token_count = 0
    l = len(text)
    cmdscope = False
    valuelist = False # Value list.
    brcparens = []
    S = {"i": 0, "line": 1, "kind": ""}
    S["start"] = S["end"] = -1

    # Adds the token to tokens array.
    def add_token():
        nonlocal token_count, ttypes

        if tokens and ttids:
            prevtk = tokens[ttids[-1]]

            # Keyword reset.
            if (kind("tkSTR") and (prevtk["kind"] == "tkCMD" or
                (cmdscope and prevtk["kind"] == "tkTBD"))):
                if (text[prevtk["start"]:prevtk["end"] + 1]
                        in KEYWORDS):
                    prevtk["kind"] = "tkKYW"

            # Reset: default $("cmd-string")
            elif (kind("tkVAR") and S["end"] - S["start"] == 0
                and (prevtk["kind"] == "tkCMD" or (
                cmdscope and prevtk["kind"] == "tkTBD"))):
                if text[prevtk["start"]:prevtk["end"] + 1] == "default":
                    prevtk["kind"] = "tkKYW"

            elif valuelist and S["kind"] == "tkFLG" and S["start"] == S["end"]:
                S["kind"] = "tkFOPT" # Hyphen.

            # When parsing a value list '--flag=()', that is not a
            # string/commang-string should be considered a value.
            elif valuelist and S["kind"] in ("tkCMD", "tkTBD"):
                S["kind"] = "tkFVAL"

            # 'Merge' tkTBD tokens if possible.
            elif (kind("tkTBD") and prevtk["kind"] == "tkTBD" and
                  prevtk["line"] == S["line"] and
                  S["start"] - prevtk["end"] == 1):
                prevtk["end"] = S["end"]
                S["kind"] = ""
                return

            elif kind("tkCMD") or kind("tkTBD"):
                # Reverse loop to get find first command/flag tokens.
                lastpassed = ""
                for i in range(token_count - 1, -1, -1):
                    lkind = ttypes[i]
                    if lkind in ("tkCMD", "tkFLG"):
                        lastpassed = lkind
                        break

                # Handle: 'program = --flag::f=123'
                if (prevtk["kind"] == "tkASG" and
                    prevtk["line"] == S["line"] and
                    lastpassed == "tkFLG"):
                    S["kind"] = "tkFVAL"

                if S["kind"] != "tkFVAL":
                    prevtk2 = tokens[ttids[-2]]["kind"]

                    # Flag alias '::' reset.
                    if (prevtk["kind"] == "tkDCLN" and prevtk2 == "tkDCLN"):
                        S["kind"] = "tkFLGA"

                    # Setting/variable value reset.
                    if prevtk["kind"] == "tkASG" and prevtk2 in ("tkSTN", "tkVAR"):
                        S["kind"] = "tkAVAL"

        # Reset when single '$'.
        if kind("tkVAR") and S["end"] - S["start"] == 0:
            S["kind"] = "tkDLS"

        # If a brace token, reset kind to brace type.
        if kind("tkBRC"): S["kind"] = BRCTOKENS.get(text[S["start"]])

        # Universal command multi-char reset.
        if kind("tkMTL") and (not tokens or tokens[-1]["kind"] != "tkASG"):
            S["kind"] = "tkCMD"

        ttypes[token_count] = S["kind"]
        if S["kind"] not in ("tkCMT", "tkNL", "tkEOP"):
            # Track token ids to help with parsing.
            dtids[token_count] = ttids[-1] if token_count and ttids else 0
            ttids.append(token_count)

        copy = dict(S)
        del copy["i"]
        if S.get("last", False):
            del S["last"]
            del copy["last"]
        copy["tid"] = token_count
        tokens.append(copy)
        S["kind"] = ""

        if S.get("lines", False):
            del S["lines"]

        token_count += 1

    # Checks if token is at needed char index.
    def charpos(pos):
        return S["i"] - S["start"] == pos - 1

    # Checks state object kind matches provided kind.
    def kind(s):
        return S["kind"] == s

    # Forward loop x amount.
    def forward(amount):
        S["i"] += amount

    # Rollback loop x amount.
    def rollback(amount):
        S["i"] -= amount

    # Get previous iteration char.
    def prevchar():
        return text[S["i"] - 1]

    # Tokenizer loop functions.

    def tk_stn():
        if S["i"] - S["start"] > 0 and not (c.isalnum()):
            rollback(1)
            S["end"] = S["i"]
            add_token()

    def tk_var():
        if S["i"] - S["start"] > 0 and not (c.isalnum() or c == C_UNDERSCORE):
            rollback(1)
            S["end"] = S["i"]
            add_token()

    def tk_flg():
        if S["i"] - S["start"] > 0 and not (c.isalnum() or c == C_HYPHEN):
            rollback(1)
            S["end"] = S["i"]
            add_token()

    def tk_cmd():
        if not (c.isalnum() or c in (C_HYPHEN, C_ESCAPE) or
                (prevchar() == C_ESCAPE)):  # Allow escaped chars.
            rollback(1)
            S["end"] = S["i"]
            add_token()

    def tk_cmt():
        if c == C_NL:
            rollback(1)
            S["end"] = S["i"]
            add_token()

    def tk_str():
        # Store initial line where string starts.
        if "lines" not in S:
            S["lines"] = [S["line"], -1]

        # Account for '\n's in string to track where string ends
        if c == C_NL:
            S["line"] += 1

            LINESTARTS.setdefault(S["line"], S["i"]);

        if (not charpos(1) and c == text[S["start"]] and
                prevchar() != C_ESCAPE):
            S["end"] = S["i"]
            S["lines"][1] = S["line"]
            add_token()

    def tk_tbd():  # Determine in parser.
        S["end"] = S["i"]
        if c == C_NL or (c in (
                C_SPACE, C_TAB, C_DOLLARSIGN, C_ATSIGN,
                C_PIPE, C_LCURLY, C_RCURLY, C_LBRACE,
                C_RBRACE, C_LPAREN, C_RPAREN, C_HYPHEN,
                C_QMARK, C_ASTERISK
            ) and (prevchar() != C_ESCAPE)):
            if c not in (C_NL, C_SPACE, C_TAB):
                rollback(1)
                S["end"] = S["i"]
            else:
                # Let '\n' pass through to increment line count.
                if c == C_NL: rollback(1)
                S["end"] -= 1
            add_token()

    def tk_brc():
        nonlocal cmdscope, valuelist, brcparens  # [https://stackoverflow.com/a/8448011]
        if c == C_LPAREN:
            if tokens[ttids[-1]]["kind"] != "tkDLS":
                valuelist = True
                brcparens.append(0) # Value list.
            else: brcparens.append(1) # Command-string.
        elif c == C_RPAREN:
            if brcparens.pop() == 0:
                valuelist = False
        elif c == C_LBRACE: cmdscope = True
        elif c == C_RBRACE: cmdscope = False
        S["end"] = S["i"]
        add_token()

    def tk_def():
        S["end"] = S["i"]
        add_token()

    def tk_eop():  # Determine in parser.
        S["end"] = S["i"]
        if c in (C_SPACE, C_TAB, C_NL):
            S["end"] -= 1
        add_token()

    DISPATCH = {
        "tkSTN": tk_stn,
        "tkVAR": tk_var,
        "tkFLG": tk_flg,
        "tkCMD": tk_cmd,
        "tkCMT": tk_cmt,
        "tkSTR": tk_str,
        "tkTBD": tk_tbd,
        "tkBRC": tk_brc,
        "tkDEF": tk_def
    }

    while S["i"] < l:
        c = text[S["i"]]

        # Add 'last' key on last iteration.
        if S["i"] == l - 1: S["last"] = True

        if not S["kind"]:
            if c in (C_SPACE, C_TAB):
                forward(1)
                continue

            if c == C_NL:
                S["line"] += 1
                LINESTARTS.setdefault(S["line"], S["i"]);

            S["start"] = S["i"]
            S["kind"] = SOT.get(c, "tkTBD")
            if S["kind"] == "tkTBD":
                if ((not cmdscope and c.isalnum()) or
                    (cmdscope and c not in XCSCOPES and c.isalpha())):
                    S["kind"] = "tkCMD"

        DISPATCH.get(S["kind"], tk_def)()

        # Run on last iteration.
        if S.get("last", False): tk_eop()

        forward(1)

    # To avoid post parsing checks, add a special end-of-parsing token.
    S["kind"] = "tkEOP"
    S["start"] = -1
    S["end"] = -1
    add_token()

    return (tokens, ttypes, ttids, dtids)
