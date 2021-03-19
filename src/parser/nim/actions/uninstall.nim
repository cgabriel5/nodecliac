import std/[os, osproc, asyncdispatch, json, strformat, re, strutils]

import ../utils/[chalk, paths]

proc nlcli_uninstall*(s: string = "{}") {.async.} =
    let ncliacdir = paths["ncliacdir"]
    var bashrcpath = paths["bashrcpath"]
    let setupfilepath = paths["setupfilepath"]

    let jdata = parseJSON(s)
    let rcfile = jdata{"rcfile"}.getStr()

    # [https://stackoverflow.com/a/84899]
    discard execProcess("sudo sh -c '' > /dev/null 2>&1") # Prompt password.

    # Delete nodecliac dir.
    if dirExists(ncliacdir): removeDir(ncliacdir)

    # Get bashrc file contents.
    if rcfile.len != 0: bashrcpath = rcfile
    else:
        if fileExists(setupfilepath):
            let res = readFile(setupfilepath)
            if res.len != 0:
                bashrcpath = parseJSON(res){"rcfile"}.getStr(bashrcpath)

    # Remove .rcfile modifications.
    if bashrcpath.len != 0:
        if fileExists(bashrcpath):
            var res = readFile(bashrcpath)
            if res.contains(re("^ncliac=~", {reMultiLine})):
                res = res.replace(re("""([# \t]*)\bncliac.*"\$ncliac";?\n?"""), "")
                writeFile(bashrcpath, res)

                let varg1 = "success".chalk("green")
                let varg2 = bashrcpath.chalk("bold")
                echo fmt"{varg1} reverted {varg2} changes."

    # Remove bin file.
    let binfilepath = "/usr/local/bin/nodecliac"
    if fileExists(binfilepath) and "#!/bin/bash" in readFile(binfilepath).strip():
        discard execProcess(fmt"sudo rm -rf {binfilepath} > /dev/null 2>&1")
        echo "success".chalk("green") & " removed nodecliac bin file."
