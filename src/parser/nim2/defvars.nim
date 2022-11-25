import std/[os, tables]

import utils/[osutils]

# Builtin variables.
proc builtins*(cmdname: string): Table[string, string] =
    return {
        "HOME": os.getEnv("HOME"),
        "OS": platform(),
        "COMMAND": cmdname,
        "PATH": "~/.nodecliac/registry/" & cmdname
    }.toTable
