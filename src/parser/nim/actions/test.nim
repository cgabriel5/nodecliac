import os

proc test() {.async.} =
    let errscript =  fmt"{hdir}/.nodecliac/src/main/test.sh"
    if not fileExists(errscript):
        quit("File " & errscript.chalk("bold") & " doesn't exit.")

    # Remove provided packages.
    for pkg in paramsargs:
        let pkgpath = fmt"{registrypath}/{pkg}"

        if not dirExists(pkgpath): continue
        let test = fmt"{pkgpath}/{pkg}.tests.sh"
        if not fileExists(test): continue

        let cmd = fmt"{errscript} -p true -f true -t {test}"
        echo execProcess(cmd).strip()
