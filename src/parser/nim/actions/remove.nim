proc remove() {.async.} =
    # Empty registry when `--all` flag is provided.
    if all:
        removeDir(registrypath)
        createDir(registrypath)
        paramsargs.setLen(0) # Empty array to skip loop.

    # Remove provided packages.
    for pkg in paramsargs:
        let pkgpath = fmt"{registrypath}/{pkg}"

        if dirExists(pkgpath): removeDir(pkgpath)
