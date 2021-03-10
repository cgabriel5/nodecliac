import os, asyncdispatch, json, strformat

import ../utils/[chalk, paths]

proc nlcli_link*(s: string = "{}") {.async.} =
    let registrypath = paths["registrypath"]

    let jdata = parseJSON(s)
    let path = jdata{"path"}.getStr()

    let p = (
        if path.len != 0 and not isAbsolute(path):
            absolutePath(path)
        else: ""
    )

    let cwd = if p.len != 0: p else: parentDir(currentSourcePath())
    let dirname = splitPath(cwd).tail
    let destination = fmt"{registrypath}/{dirname}"

    # If folder exists give error.
    if not dirExists(cwd): quit() # Confirm cwd exists.

    # If folder exists give error.
    if dirExists(destination) or symlinkExists(destination):
        # Check if folder is a symlink.
        let `type`= if symlinkExists(destination): "Symlink " else: ""
        quit(`type` & dirname.chalk("bold") & "/ exists. Remove it and try again.")

    createSymlink(cwd, destination) # Create symlink.
