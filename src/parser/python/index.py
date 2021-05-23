#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse, sys, re

import utils.quit
from utils.fs import info
from utils.chalk import chalk

if len(sys.argv) == 1: quit()

# [https://stackoverflow.com/a/30493366]
# [https://blender.stackexchange.com/a/8405]
# [https://stackoverflow.com/a/12818237]
cliparser = argparse.ArgumentParser()
cliparser.add_argument("--igc", default=False)
cliparser.add_argument("--test", default=False)
cliparser.add_argument("--print", default=False)
cliparser.add_argument("--trace", default="")
cliparser.add_argument("action", default="")
# [https://stackoverflow.com/a/15301183]
cliparser.add_argument("--indent", default="s:4")
cliparser.add_argument("--source", default="")
args, unknown = cliparser.parse_known_args()

igc = args.igc
test = args.test
print_ = args.print
trace = args.trace
action = args.action
indent = args.indent
source = args.source
formatting = action == "format"

fmtinfo = ['\t', 1] # (char, amount)
# Parse/validate indentation.
if formatting and indent != "":
    r = r"^(s|t):\d+$"
    re.search(r, indent)
    # [https://stackoverflow.com/a/38342048]
    if re.search(r, indent) == None:
        print("Invalid indentation string.")
        quit()
    components = indent.split(":", 2)
    fmtinfo[0] = ' ' if components[0] == 's' else '\t'
    fmtinfo[1] = int(components[1])

# Source must be provided.
if not source:
    print("Please provide a " + chalk("--source", "bold") + " path.")
    exit()

# Breakdown path.
fi = info(source)
extension = fi["ext"]
cmdname = re.sub(rf"\.{extension}$", "", fi["name"]) # [TODO] `replace`
dirname = fi["dirname"]
