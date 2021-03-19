import std/[os, json, strutils]

from ../utils/osutils import platform

proc nlcli_make*(s: string = "{}") {.async.} =
    let jdata = parseJSON(s)
    let input = jdata["__input"].getStr()

    # Run Nim binary if it exists.
    let hdir = getEnv("HOME")
    let binfilepath = fmt"{hdir}/.nodecliac/src/bin/nodecliac.{platform()}"
    if fileExists(binfilepath):
        let res = execProcess(binfilepath & " " & input).strip()
        if res.len != 0: echo res
