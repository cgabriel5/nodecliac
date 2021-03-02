import os

proc make() {.async.} =
    # Run Nim binary if it exists.
    let hdir = os.getEnv("HOME")
    let binfilepath = fmt"{hdir}/.nodecliac/src/bin/nodecliac.{platform()}"
    if fileExists(binfilepath):
        discard execProcess(binfilepath & " " & arguments.join(" "))
