import os, asyncdispatch, httpclient, json, strformat
import re, osproc, strutils, times

import ../utils/[chalk, paths, osutils]

proc nlcli_add*(s: string = "{}") {.async.} =
    let cwd = paths["cwd"]
    let hdir = paths["homedir"]
    let registrypath = paths["registrypath"]

    let jdata = parseJSON(s)
    let force = jdata{"force"}.getBool()
    let skipval = jdata{"skip-val"}.getBool()
    let path = jdata{"path"}.getStr()
    var repo = jdata{"repo"}.getStr()

    # Checks whether completion package has a valid base structure.
    #
    # @param  {string} command - The completion package command.
    # @param  {string} dir - The directory path of package.
    # @param  {boolean} _ - Provide when checking multiple lines.
    # @return {boolean} - The validation check result.
    proc check(command, dir: string, _: bool = false): int =
        var r = 1

        let prefix = "Error".chalk("red") & " Package missing ./"
        proc perror(file: string) =
            r = 0
            echo  prefix & file.chalk("bold")

        # If a single item is provided a folder contents
        # check is performed.
        if not _:
            # Validate repo's basic package structure: Must
            # contain: acmap, acdef, and config.acdef root files.
            const ini = "package.ini"
            let acmap = fmt"{command}.acmap"
            let acdef = fmt"{command}.acdef"
            let config = fmt".{command}.config.acdef"
            let inipath = fmt"{dir}/{ini}"
            let acmappath = fmt"{dir}/{acmap}"
            let acdefpath = fmt"{dir}/{acdef}"
            let configpath = fmt"{dir}/{config}"
            if not fileExists(acmappath): perror(acmap)
            if not fileExists(acdefpath): perror(acdef)
            if not fileExists(configpath): perror(config)
            if not fileExists(inipath): perror(ini)
        else:
            # Check for multiple lines individually.
            let contents = dir.strip(trailing=true)

            if contents.find(re"svn: E[0-9]{6,6}") != -1:
                echo "Provided URL does not exist."

            const ini = "package.ini"
            let acmap = fmt"{command}.acmap"
            let acdef = fmt"{command}.acdef"
            let config = fmt".{command}.config.acdef"

            const t = "^$1$" # RegExp string template.
            const REM = reMultiLine
            if contents.find(re(t % [ini], {REM})) == -1: perror(ini)
            if contents.find(re(t % [acmap], {REM})) == -1: perror(acmap)
            if contents.find(re(t % [acdef], {REM})) == -1: perror(acdef)
            if contents.find(re(t % [config], {REM})) == -1: perror(config)

        return r

    let p = (
        if path.len != 0 and not isAbsolute(path):
            absolutePath(path)
        else: ""
    )

    var sub = ""
    if repo.len != 0 and path.len == 0:
        const trunk = "/trunk/"
        const TL = trunk.len
        let tindex = repo.find(trunk)
        if tindex != 0:
            repo = repo.substr(0, tindex - 1)
            sub = repo.substr(tindex + TL)

    # Extract possibly provided branch name.
    var branch = "master"
    let hash_index = repo.find('#')
    if hash_index != -1:
        branch = repo.substr(hash_index + 1)
        repo = repo.substr(0, hash_index)

    if sub.endsWith('/'): sub.setLen(sub.high)
    if repo.endsWith('/'): repo.setLen(repo.high)

    if repo.len == 0:
        let cwd = if p.len != 0: p else: cwd
        let dirname = splitPath(cwd).tail # Get package name.
        let pkgpath = joinPath(registrypath, dirname)

        # If package exists error.
        if dirExists(pkgpath):
            # Check if folder is a symlink.
            let `type` = if symlinkExists(pkgpath): "Symlink " else: ""
            # quit(`type` & dirname.chalk("bold") & "/ exists in registry. Remove it and try again.")
            quit(fmt"""{`type`}{dirname.chalk("bold")}/ exists in registry. Remove it and try again.""")

        # Validate package base structure.
        if not skipval and check(dirname, cwd) == 0: quit()

        # Skip size check when --force is provided.
        if not force:
            var shellcmd = ""
            if platform() == "macosx":
                # [https://serverfault.com/a/913506]
                shellcmd = fmt"""du -skL "{cwd}" | grep -oE '[0-9]+' | head -n1"""
            else:
                # [https://stackoverflow.com/a/22295129]
                shellcmd = fmt"""du --apparent-size -skL "{cwd}" | grep -oE '[0-9]+' | head -n1"""

            let size = execProcess(shellcmd)

            # Anything larger than 10MB must be force added.
            # if execProcess(fmt"""perl -e 'print int('"{size}"') > 10000'""")-n "$()":
            if parseInt(size) > 10000:
                quit(fmt"""{dirname.chalk("bold")}/ exceeds 10MB. Use --force to add package anyway.""")

        createDir(pkgpath)
        copyDir(cwd, registrypath)

    else:

        var uri, cmd, res: string = ""
        var rname = splitPath(repo).tail
        # let timestamp="$(perl -MTime::HiRes=time -e 'print int(time() * 1000);')"
        let timestamp = intToStr(getTime().toUnix().int)
        let output=fmt"""{hdir}/Downloads/{rname}-{timestamp}"""

        # Reset rname if subdirectory is provided.
        if sub.len != 0: rname = splitPath(sub).tail

        # If package exists error.
        let pkgpath = fmt"{registrypath}/{rname}"
        if dirExists(pkgpath):
            # Check if folder is a symlink.
            let `type` = if symlinkExists(pkgpath): "Symlink " else: ""
            quit(fmt"""{`type`}{rname.chalk("bold")}/ exists in registry. Remove it and try again.""")

        # Use git: [https://stackoverflow.com/a/60254704]
        if sub.len == 0:
            # Ensure repo exists.
            uri = fmt"https://api.github.com/repos/{repo}/branches/{branch}"
            var client = newAsyncHttpClient()
            res = await client.getContent(uri)

            if res.len == 0: quit("Provided URL does not exist.")

            # Download repo with git.
            uri = fmt"git@github.com:{repo}.git"
            # [https://stackoverflow.com/a/42932348]
            cmd = fmt"""git clone "{uri}" "{output}" > /dev/null 2>&1"""
            res = execProcess(cmd)
        else:
            # Use svn: [https://stackoverflow.com/a/18194523]

            # First check that svn is installed.
            if execProcess("command -v svn").strip(trailing = true).len == 0:
                quit("`svn' is not installed.")

            # Check that repo exists.
            uri = fmt"https://github.com/{repo}/trunk/{sub}"
            if branch != "master": uri = fmt"https://github.com/{repo}/branches/{branch}/{sub}"
            res = execProcess(fmt"""svn ls "{uri}"""")

            # Use `svn ls` output here to validate package base structure.
            if not skipval and check(rname, res, true) == 0: quit()

            if res.find(re"svn: E[0-9]{6,6}") != -1:
                quit("Provided URL does not exist.")

            # Use svn to download provided sub directory.
            cmd = fmt"""svn export "{uri}" "{output}" > /dev/null 2>&1"""
            res = execProcess(cmd)

        # Validate package base structure.
        if not skipval and check(rname, output) == 0: quit()

        # Move repo to registry.
        if not dirExists(registrypath):
            quit(fmt"""nodecliac registry {registrypath.chalk("bold")} doesn't exist.""")
        # Delete existing registry package if it exists.
        if dirExists(pkgpath): removeDir(pkgpath)
        moveDir(output, pkgpath)
