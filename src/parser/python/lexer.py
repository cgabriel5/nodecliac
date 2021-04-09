#!/usr/bin/env python3
# -*- coding: utf-8 -*-

C_NL = '\n'
C_TAB = '\t'
C_SPACE = ' '
C_HYPHEN = '-'
C_ESCAPE = '\\'
C_LPAREN = '('
C_RPAREN = ')'

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
    "\n": "tkNL"
}

KEYWORDS = ["default", "context", "filedir", "exclude"]

def tokenizer(text):
    c = ''
    tokens = []
    l = len(text)
    flgopts = False
    S = {"i": 0, "line": 1, "kind": ""}
    S["start"] = S["end"] = -1

    # Adds the token to tokens array.
    def add_node():
        if tokens:

            # Keyword reset.
            if kind("tkSTR") and tokens[-1]["kind"] == "tkCMD":
                if (text[tokens[-1]["start"]:tokens[-1]["end"] + 1]
                        in KEYWORDS):
                    tokens[-1]["kind"] = "tkKYW"

            # Reset long form: --flag=(option1 option2)
            elif (tokens[-1]["kind"] == "tkFLG" and
                  text[tokens[-1]["start"]:tokens[-1]["end"] + 1] ==
                  C_HYPHEN):
                tokens[-1]["kind"] = "tkFOPT"
                if S["kind"] == "tkCMD":
                    S["kind"] = "tkFVAL"

            # Reset: --flag=(option1 option2)
            elif flgopts and kind("tkCMD"):
                S["kind"] = "tkFVAL"

            # 'Merge' tkTBD tokens if possible.
            elif (kind("tkTBD") and tokens[-1]["kind"] == "tkTBD" and
                  tokens[-1]["line"] == S["line"] and
                  S["start"] - tokens[-1]["end"] == 1):
                tokens[-1]["end"] = S["end"]
                S["kind"] = ""
                return

        # Reset when single '$'.
        if kind("tkVAR") and S["end"] - S["start"] == 0:
            S["kind"] = "tkDLS"

        copy = dict(S)
        del copy["i"]
        tokens.append(copy)
        S["kind"] = ""

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

    def tk_stn_var_flg():
        if S["i"] - S["start"] > 0 and not (c.isalnum() or c == C_HYPHEN):
            rollback(1)
            S["end"] = S["i"]
            add_node()

    def tk_cmd():
        if not (c.isalnum() or c in (C_HYPHEN, C_ESCAPE) or
                (prevchar() == C_ESCAPE)):  # Allow escaped chars.
            rollback(1)
            S["end"] = S["i"]
            add_node()

    def tk_cmt():
        if c == C_NL:
            rollback(1)
            S["end"] = S["i"]
            add_node()

    def tk_str():
        if (not charpos(1) and c == text[S["start"]] and
                prevchar() != C_ESCAPE):
            S["end"] = S["i"]
            add_node()

    def tk_tbd():  # Determine in parser.
        S["end"] = S["i"]
        if c in (C_SPACE, C_TAB, C_NL):
            S["end"] -= 1
        add_node()

    def tk_brc():
        nonlocal flgopts  # [https://stackoverflow.com/a/8448011]
        if c == C_LPAREN:
            flgopts = True
        elif c == C_RPAREN:
            flgopts = False
        S["end"] = S["i"]
        add_node()

    def tk_def():
        S["end"] = S["i"]
        add_node()

    DISPATCH = {
        "tkSTN": tk_stn_var_flg,
        "tkVAR": tk_stn_var_flg,
        "tkFLG": tk_stn_var_flg,
        "tkCMD": tk_cmd,
        "tkCMT": tk_cmt,
        "tkSTR": tk_str,
        "tkTBD": tk_tbd,
        "tkBRC": tk_brc,
        "tkDEF": tk_def
    }

    while S["i"] < l:
        c = text[S["i"]]

        if not S["kind"]:
            if c in (C_SPACE, C_TAB):
                forward(1)
                continue

            if c == C_NL:
                S["line"] += 1

            S["start"] = S["i"]
            S["kind"] = SOT.get(c, "tkTBD")
            if S["kind"] == "tkTBD":
                if c.isalnum():
                    S["kind"] = "tkCMD"

        DISPATCH.get(S["kind"], tk_def)()

        forward(1)

    return tokens
