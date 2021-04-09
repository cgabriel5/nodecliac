#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from lexer import tokenizer
# from pathlib import Path  # [https://stackoverflow.com/a/66195538]

def main():
    if __name__ == "__main__":

        # hdir = str(Path.home())
        # f = open(hdir + "/.nodecliac/registry/nodecliac/nodecliac.acmap", "r")
        # text = f.read()

        f = open("../../../resources/packages/nodecliac/nodecliac.acmap", "r")
        text = f.read()

        tokens = tokenizer(text)

        print("Token_Count: [" + str(len(tokens)) + "]")
        for token in tokens:
            kind = token["kind"]
            start = token["start"]
            end = token["end"]
            line = token["line"]
            if kind == "tkNL":
                continue
            print("L: " + str(line) + ", K: [" + kind + "] V: [" +
                  text[start:end + 1] + "] ["+str(start), ", " +
                  str(end) + "]")

main()
