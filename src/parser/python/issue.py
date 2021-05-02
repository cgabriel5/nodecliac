#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys

class Issue:
    def warn(self, filename, line, col, message):
        itype = "\033[33;1mwarn:\033[0m"
        fileinfo = f"\033[1m{filename}:{line}:{col}:\033[0m"

        print(f"{fileinfo} {itype} {message}")

    def error(self, filename, line, col, message):
        itype = "\033[31;1merror:\033[0m"
        fileinfo = f"\033[1m{filename}:{line}:{col}:\033[0m"

        sys.exit(f"{fileinfo} {itype} {message}")
