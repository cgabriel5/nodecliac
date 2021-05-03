#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys, ntpath

from lexer import tokenizer, LINESTARTS
from parser import parser
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

        (tokens, ttypes) = tokenizer(text)
        filename = ntpath.basename(filepath)
        BRANCHES = parser(tokens, ttypes, text, LINESTARTS, filename)

        print("\nBRANCHES", len(BRANCHES), "\n")
        for branch in BRANCHES:
            output = ""
            tids = []
            for token in branch:
                start = token["start"]
                end = token["end"]
                tid = token["tid"]
                output += text[start:end + 1]
                tids.append(tid)
                # print(token)

            # print("[tids]", tids)
            print("[BRANCH] <" + output + ">")

            print("")

main()
