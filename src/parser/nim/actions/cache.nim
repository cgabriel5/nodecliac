proc cache() {.async.} =
    let cachepath = paths["cachepath"]

    initconfig()

    # Clear cache...
    if dirExists(cachepath) and ccache:
        const filetypes = { pcFile, pcLinkToFile }
        for kind, path in walkDir(cachepath):
            if kind in filetypes: removeFile(path)
        let success = "success".chalk("green")
        echo fmt"{success} Cleared cache."

    if setlevel:
        if level[0] in {'0' .. '9'}:
            if level[0] notin {'0' .. '2'}: level = "1"
            setsetting("cache", level)
        else:
            stdout.write(getsetting("cache"))
