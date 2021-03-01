#!/usr/bin/env nim

import json, sequtils, tables, os
import strutils except escape

import utils/[chalk, argvparse2, paths, config]

var rcfile = ""
var prcommand = ""
var enablencliac: bool
var disablencliac: bool
var debug_enable: bool
var debug_disable: bool
var debug_script = ""
var command = ""
var version: bool
var ccache: bool
var level = ""
var force: bool
var setlevel: bool
var all: bool
var path = ""
var skipval: bool
var repo = ""

var paramsargs: seq[string] = @[]

let args = argvparse()
if args.len == 0: quit()

for index, arg in args:
    let arg = arg[]
    let key = arg.key
    let val = arg.val
    let `type` = arg.`type`

    if index == 0: command = key
    else:
        case key:
        of "version": version = true
        of "command": prcommand = val
        of "enable":
            enablencliac = true

            if command == "status":
                enablencliac = true
            else:
                debug_enable = true

        of "disable":
            disablencliac = true

            if command == "status":
                disablencliac = true
            else:
                debug_disable = true

        of "script": debug_script = val
        of "clear": ccache = true
        of "level": setlevel = true; level = val
        of "rcfile": rcfile = val
        of "all": all = true
        of "path": path = val
        of "force": force = true
        of "skip-val": skipval = true
        of "repo": repo = val
        else: discard

    if `type` == "positional": paramsargs.add(key)

# If no command given but '--version' flag supplied show version.
if command.len == 0 and version:
    # FIX: Use ~/.nodecliac/.setup.db.json file.
    let jdata = parseFile("../../../package.json")
    quit(jdata["version"].getStr())

# Allowed actions.
const ac_main: seq[string] = @["make", "format", "test", "debug", "bin", "init"]
const ac_mis: seq[string] = @["print", "setup", "status", "registry", "uninstall", "cache"]
const ac_pkg: seq[string] = @["add", "remove", "link", "unlink", "enable", "disable"]
const actions = concat(ac_main, ac_main, ac_pkg)

let hdir = os.getEnv("HOME")
let registrypath = paths["registrypath"]
let filename = currentSourcePath()
let cwd = paths["cwd"]

# Exit if invalid command.
let tstring = "Unknown command $1."
if command notin actions: quit(tstring % [command.chalk("bold")])

include actions/[add, bin, cache]

# include actions/[add]

