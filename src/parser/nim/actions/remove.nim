import std/[os, asyncdispatch, json, strformat, sequtils]

import ../utils/paths

proc nlcli_remove*(s: string = "{}") {.async.} =
    let registrypath = paths["registrypath"]

    let jdata = parseJSON(s)
    let all = jdata{"all"}.getBool()
    var packages = toSeq(jdata{"_"})
    packages.delete(0, 0)

    # Empty registry when `--all` flag is provided.
    if all:
        removeDir(registrypath)
        createDir(registrypath)
        packages.setLen(0) # Empty array to skip loop.

    # Remove provided packages.
    for pkg in packages:
        let pkgpath = fmt"{registrypath}/{pkg}"

        if dirExists(pkgpath): removeDir(pkgpath)
