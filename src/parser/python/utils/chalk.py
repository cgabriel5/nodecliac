#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Quick and light-weight port of 'nim/utils/chalk.nim'.

import re

lookup = {
   "bold": 1,
   "dim": 2,
   "italic": 3,
   "underline": 4,
   "blink": 5,
   "blinkrapid": 6,
   "reverse": 7,
   "hidden": 8,
   "strikethrough": 9,
    #
   "black": 30,
   "red": 31,
   "green": 32,
   "yellow": 33,
   "blue": 34,
   "magenta": 35,
   "cyan": 36,
   "white": 37,
   "8bit": 38,
   "default": 39,
   "bgblack": 40,
   "bgred": 41,
   "bggreen": 42,
   "bgyellow": 43,
   "bgblue": 44,
   "bgmagenta": 45,
   "bgcyan": 46,
   "bgwhite": 47,
   "bg8bit": 48,
   "bgdefault": 49
}

r = r"\x1b\[[0-9;]*[mG]" # [https://superuser.com/a/561105]

# Simple colored logging inspired by: [https://www.npmjs.com/package/chalk]
#
# @param  {array} styles - List of styles to apply.
# @param  {bool} debug - Returns the actual ANSI escape string.
# @return {string} - The highlighted string or ANSI escaped string.
def chalk(s, *styles):
    starting = "\033[" # [https://forum.nim-lang.org/t/3556#25477]
    closing = "\033[0m"
    l = len(styles)
    i = 0
    str_ = s
    for style in styles:
        if style == "strip": str_ = re.sub(r, "", str_)
        elif style in lookup:
            starting += str(lookup[style])
            if i != l - 1: starting += ";"
        i += 1
    return starting + "m" + str_ + closing

# # Works but gives warning: "FutureWarning: Possible nested set at position 15"
# # [https://github.com/chalk/ansi-regex/blob/main/index.js]
# pattern = \
#     "[\\u001B\\u009B][[\\]()#;?]*(?:(?:(?:[a-zA-Z\\d]*(?:;[-a-zA-Z\\d\\/#&.:=?%@~_]*)*)?\\u0007)" + "|" + \
#     "(?:(?:\\d{1,4}(?:;\\d{0,4})*)?[\\dA-PR-TZcf-ntqry=><~]))"

# def stripansi(s):
#     return re.sub(pattern, "", s, flags=re.MULTILINE)

# [https://stackoverflow.com/a/14693789]
def stripansi(s):
    ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
    return ansi_escape.sub("", s)
