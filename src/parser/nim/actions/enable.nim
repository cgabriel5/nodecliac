import os, asyncdispatch, json, sequtils, algorithm, strformat, strutils, re

import ../utils/[paths]

proc nlcli_enable*(s: string = "{}") {.async.} =
    let registrypath = paths["registrypath"]

    let jdata = parseJSON(s)
    let all = jdata{"all"}.getBool()
    var packages = toSeq(jdata{"_"}).mapIt(it.getStr())
    let action = packages[0].string
    packages.delete(0, 0)
    let state = if action == "enable": "false" else: "true"

    # Get all packages when '--all' is provided.
    if all:
        packages.setLen(0)
        packages = (
            const dirtypes = {pcDir, pcLinkToDir}
            for kind, path in walkDir(registrypath):
                if kind notin dirtypes: continue
                let parts = splitPath(path)
                packages.add(parts.tail)
            packages.sort()
            packages
        )

    # Loop over packages and remove each if its exists.
    for pkg in packages:
        let filepath = fmt"{registrypath}/{pkg}/.{pkg}.config.acdef"
        let resolved_path = absolutePath(filepath)
        # Workout symlinks: expandSymlink(), symlinkExists()

        if not fileExists(resolved_path): continue
        var contents = readFile(resolved_path).strip()

        contents = contents.replace(re("^@disable[^\n]*", {reMultiLine}), "").strip()
        contents &= fmt"\n@disable = {state}\n"
        contents = contents.replace(re("^\n/", {reMultiLine}), "") # Remove newlines.
        contents = contents.replace(re("\n", {reMultiLine}), "\n\n") # Add newline after header.

        writeFile(filepath, contents)
