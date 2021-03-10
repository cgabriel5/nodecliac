#!/usr/bin/env nim

# Compile with '-no-pie' to generated an executable and not shared library:
# [https://forum.openframeworks.cc/t/ubuntu-18-04-mistaking-executable-as-shared-library/30873]
# [https://askubuntu.com/q/1071374]
# [https://stackoverflow.com/a/45332687]
# [https://askubuntu.com/a/960212]
# [https://stackoverflow.com/a/50615370]
# [https://github.com/nim-lang/Nim/issues/506]
# [https://nim-lang.org/docs/manual.html#implementation-specific-pragmas-passl-pragma]
{.passL: "-no-pie".}

from strutils import `%`
from sets import contains
from tables import toTable, `[]`
from asyncdispatch import asyncCheck
from json import parseFile, `[]`, getStr

import utils/[argvparse2, chalk]
import actions/[
            make, format, test, debug, bin, init,
            print, setup, status, registry, uninstall, cache,
            add, remove, link, unlink, enable, disable
        ]
include actions/tablify

let (args, jstr, usedflags, positional) = argvparse()
if args.len == 0: quit()
let command: string = if positional.len > 0: positional[0] else: ""

# If no command given but '--version' flag supplied show version.
if command.len == 0 and usedflags.contains("version"):
    # FIX: Use ~/.nodecliac/.setup.db.json file.
    let jdata = parseFile("../../../package.json")
    quit(jdata["version"].getStr())

# Allowed actions.
const ac_main = ["make", "format", "test", "debug", "bin", "init"]
const ac_mis = ["print", "setup", "status", "registry", "uninstall", "cache"]
const ac_pkg = ["add", "remove", "link", "unlink", "enable", "disable"]
const l1 = ac_main.len; const l2 = ac_mis.len; const l3 = ac_pkg.len
var actions: array[(l1 + l2 + l3), string]
actions[0 .. ac_main.high] = ac_main
actions[l1 .. (actions.high - l2)] = ac_mis
actions[(l1 + l2).. actions.high] = ac_pkg

# Exit if invalid command.
let tstring = "Unknown command $1."
if command notin actions: quit(tstring % [command.chalk("bold")])

asyncCheck funcs[command](jstr)
