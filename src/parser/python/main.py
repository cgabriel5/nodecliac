#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys, ntpath

from lexer import tokenizer, LINESTARTS
from parser import parser
from acdef import acdef
from pathlib import Path  # [https://stackoverflow.com/a/66195538]

def main():
    if __name__ == "__main__":

        filepath = sys.argv[1]

        try:
            hdir = str(Path.home())
            f = open(filepath)
            text = f.read()
        except FileNotFoundError:
            sys.exit(f"{filepath} does not exist.")

        filename = ntpath.basename(filepath)
        acdef(*parser(filename, text, LINESTARTS, *tokenizer(text)))

main()
