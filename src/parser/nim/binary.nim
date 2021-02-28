#!/usr/bin/env nim

import json, sequtils
import strutils except escape

import utils/[chalk, argvparse2]

let args = argvparse()
if args.len == 0: quit()
# for arg in args: echo arg[]

# Allowed actions.
const ac_main: seq[string] = @["make", "format", "test", "debug", "bin", "init"]
const ac_mis: seq[string] = @["print", "setup", "status", "registry", "uninstall", "cache"]
const ac_pkg: seq[string] = @["add", "remove", "link", "unlink", "enable", "disable"]
const actions = concat(ac_main, ac_main, ac_pkg)

# if os.paramCount() == 0: quit()
if args.len == 0: quit()

let action = args[0][].key

for arg in args:
    let arg = arg[]
    if arg.key == "version":
        let jdata = parseFile("../package.json")
        quit(jdata["version"].getStr())

let tstring = "Unknown command $1."
if action notin actions: quit(tstring % [action.chalk("bold")])

# include actions/[add]

