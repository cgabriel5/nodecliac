#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re, os, sys, argparse
from pathlib import Path

import utils.quit
from parser import parser
from utils.chalk import chalk
from utils.fs import info, write

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

# Make path absolute.
if not os.path.isabs(source): source = os.path.abspath(source)

if os.path.isdir(source):
    print("Directory provided but .acmap file path needed.")
    quit()
if not os.path.isfile(source):
    print("Path " + chalk(source, "bold") + " doesn't exist.")
    quit()

# [TODO] Look into why using `let` over `var` causes hang up when file
# is large. Possibly due to `openFileStream`?
f = open(source, "r")
res = f.read()

(
    acdef, config, keywords, filedirs,
    contexts, formatted, placeholders, tests
) = \
parser(
    action, res, cmdname,
    source, fmtinfo, trace, igc, test
)

testname = cmdname + ".tests.sh"
savename = cmdname + ".acdef"
saveconfigname = "." + cmdname + ".config.acdef"

# Only save files to disk when not testing.
if not test:
    if formatting:
        write(source, formatted)
    else:
        testpath = os.path.join(dirname, testname)
        commandpath = os.path.join(dirname, savename)
        commandconfigpath = os.path.join(dirname, saveconfigname)
        placeholderspaths = os.path.join(dirname, "placeholders")

        Path(dirname).mkdir(parents=True, exist_ok=True)
        write(commandpath, acdef + keywords + filedirs + contexts)
        write(commandconfigpath, config)

        # Save test file if tests were provided.
        if tests:
            write(testpath, tests) # [https://forum.nim-lang.org/t/5270]
            # [https://stackoverflow.com/a/7228338]
            os.chmod(testpath, 0o775) # 775 permissions

        # Create placeholder files if object is populated.
        # placeholders = placeholders
        if placeholders:
            Path(placeholderspaths).mkdir(parents=True, exist_ok=True)

            for key in placeholders:
                p = placeholderspaths + os.path.sep + key
                write(p, placeholders[key])

if print_:
    if not formatting:
        if acdef:
            print("[" + chalk(cmdname + ".acdef", "bold") + "]\n")
            print(acdef + keywords + filedirs + contexts)
            if not config: print("")
        if config:
            msg = "\n[" + chalk("." + cmdname + ".config.acdef", "bold") + "]\n"
            print(msg)
            print(config + "\n")
    else: print(formatted)

# Test (--test) purposes.
if test:
    if not formatting:
        if acdef:
            print(acdef + keywords + filedirs + contexts)
            if not config: print("")
        if config:
            if acdef: print("")
            print(config)
    else: print(formatted)
