import os, asyncdispatch, strutils, algorithm, strformat

import ../utils/[chalk, paths]

proc nlcli_registry*(s: string = "{}") {.async.} =
    let registrypath = paths["registrypath"]

    type
        Data = object
            command: string
            isdir: bool
            hasacdefs: bool
            issymlink: bool
            issymlinkdir: bool
            realpath: string
            issymlink_valid: bool

    var files: seq[Data] = @[]

    # Maps path needs to exist to list acdef files.
    if not dirExists(registrypath): quit()

    # Get list of directory command folders.
    let commands = (
        var names: seq[string] = @[]
        const dirtypes = {pcDir, pcLinkToDir}
        for kind, path in walkDir(registrypath):
            if kind notin dirtypes: continue
            let parts = splitPath(path)
            names.add(parts.tail)
        names.sort()
        names
    )
    let count = commands.len

    echo registrypath.chalk("bold", "blue") # Print header.

    # Exit if directory is empty.
    if count == 0:
        if count == 1: echo fmt"\n{count} package"
        else: echo fmt"\n{count} packages"
        quit()

    # Loop over folders to get .acdef files.
    for i, command in commands:
        # let command = commands[i]

        let filename = fmt"{command}.acdef"
        let configfilename = fmt".{command}.config.acdef"
        let acdefpath = joinPath(registrypath, command, filename)
        let configpath = joinPath(registrypath, command, configfilename)

        var data = Data(command: command)
        var check: bool

        if fileExists(acdefpath): check = true
        if fileExists(configpath) and check: data.hasacdefs = true

        # Check whether it's a symlink.
        let pkgpath = fmt"{registrypath}/{command}"
        data.isdir = dirExists(pkgpath)
        if symlinkExists(pkgpath):
            data.issymlink = true
            let resolved_path = absolutePath(pkgpath)
            data.realpath = resolved_path

            data.issymlinkdir = dirExists(resolved_path)
            data.isdir = dirExists(resolved_path)

            # Confirm symlink dir gave .acdefs.
            let sympath = joinPath(resolved_path, command, filename)
            let sympathconf = joinPath(resolved_path, command, configfilename)

            check = false
            if fileExists(sympath): check = true
            if fileExists(sympathconf) and check: data.issymlink_valid = true

        files.add(data)

    # List commands.
    if files.len != 0:
        for i, file in files:
            let command = file.command
            let isdir = file.isdir
            let hasacdefs = file.hasacdefs
            let issymlink = file.issymlink
            let issymlinkdir = file.issymlinkdir
            var realpath = file.realpath
            let issymlink_valid = file.issymlink_valid

            # Remove user name from path.
            let hdir = os.getEnv("HOME")
            if realpath.startsWith(hdir):
                realpath.removePrefix(hdir)
                realpath = "~" & realpath

            # Decorate commands.
            let bcommand = command.chalk("bold", "blue")
            let ccommand = command.chalk("bold", "cyan")
            let rcommand = command.chalk("bold", "red")
            # Row decor.
            let decor = if count != i + 1: "├── " else: "└── "

            if not issymlink:
                if isdir:
                    let dcommand = if hasacdefs: bcommand else: rcommand
                    echo fmt"{decor}{dcommand}/"
                else:
                    echo fmt"{decor}{rcommand}"
            else:
                if issymlinkdir:
                    let color = if issymlink_valid: "blue" else: "red"
                    let linkdir = realpath.chalk("bold", color)
                    echo fmt"{decor}{ccommand} -> {linkdir}/"
                else:
                    echo fmt"{decor}{ccommand} -> {realpath}"

    if count == 1: echo fmt"\n{count} package"
    else: echo fmt"\n{count} packages"
