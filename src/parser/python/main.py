#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from lexer import tokenizer, LINESTARTS
from parser import parser
from pathlib import Path  # [https://stackoverflow.com/a/66195538]

def main():
    if __name__ == "__main__":

        hdir = str(Path.home())
        f = open(hdir + "/.nodecliac/registry/alacritty/alacritty.acmap", "r")
        text = f.read()

        (tokens, ttypes) = tokenizer(text)
        BRANCHES = parser(tokens, ttypes)

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
