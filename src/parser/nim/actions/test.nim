import os, osproc, strutils, sequtils, asyncdispatch, json, strformat

import ../utils/[chalk, paths]

proc nlcli_test*(s: string = "{}") {.async.} =
    let registrypath = paths["registrypath"]

    let jdata = parseJSON(s)
    var packages = toSeq(jdata{"_"})
    packages.delete(0, 0)

    let hdir = getEnv("HOME")
    let errscript =  fmt"{hdir}/.nodecliac/src/main/test.sh"
    if not fileExists(errscript):
        quit("File " & errscript.chalk("bold") & " doesn't exit.")

    # Remove provided packages.
    for pkg in packages:
        let pkgpath = fmt"{registrypath}/{pkg}"

        if not dirExists(pkgpath): continue
        let test = fmt"{pkgpath}/{pkg}.tests.sh"
        if not fileExists(test): continue

        let cmd = fmt"{errscript} -p true -f true -t {test}"
        echo execProcess(cmd).strip()
