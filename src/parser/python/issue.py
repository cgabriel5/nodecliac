#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys

class Issue:
    def hint(self, filename, line, col, message):
        itype = "\033[32;1mHint:\033[0m"
        fileinfo = f"\033[1m{filename}({line}, {col})\033[0m"

        print(f"{fileinfo} {itype} {message}")

    def warn(self, filename, line, col, message):
        itype = "\033[33;1mWarning:\033[0m"
        fileinfo = f"\033[1m{filename}({line}, {col})\033[0m"

        print(f"{fileinfo} {itype} {message}")

    def error(self, filename, line, col, message):
        itype = "\033[31;1mError:\033[0m"
        fileinfo = f"\033[1m{filename}({line}, {col})\033[0m"

        sys.exit(f"{fileinfo} {itype} {message}")
