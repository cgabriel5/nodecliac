import std/[os, asyncdispatch, json, strformat]

import ../utils/[chalk, config, paths]

proc nlcli_cache*(s: string = "{}") {.async.} =
    let cachepath = paths["cachepath"]

    let jdata = parseJSON(s)
    let clear = jdata{"clear"}.getBool()
    var level = jdata{"level"}.getStr()

    initconfig()

    # Clear cache...
    if dirExists(cachepath) and clear:
        const filetypes = { pcFile, pcLinkToFile }
        for kind, path in walkDir(cachepath):
            if kind in filetypes: removeFile(path)
        let success = "success".chalk("green")
        echo fmt"{success} Cleared cache."

    if level.len != 0:
        if level[0] in {'0' .. '9'}:
            if level[0] notin {'0' .. '2'}: level = "1"
            setsetting("cache", level)
        else:
            stdout.write(getsetting("cache"))
