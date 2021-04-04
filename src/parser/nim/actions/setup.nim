import std/[os, osproc, times, sets, asyncdispatch, json, strutils, re, strformat]

import ../utils/[chalk, paths, osutils, text]

proc nlcli_setup*(s: string = "{}") {.async.} =
    let hdir = paths["homedir"]
    let ncliacdir = paths["ncliacdir"]
    var bashrcpath = paths["bashrcpath"]
    let mainscriptname = paths["mainscriptname"]
    var registrypath = paths["registrypath"]
    let acmapssource = paths["acmapssource"]
    var resourcespath = paths["resourcespath"]
    let resourcessrcs = paths["resourcessrcs"]
    let setupfilepath = paths["setupfilepath"]
    let testsrcpath = paths["testsrcpath"]

    let jdata = parseJSON(s)
    let force = jdata{"force"}.getBool()
    let update = jdata{"update"}.getBool()
    let rcfile = jdata{"rcfile"}.getStr()
    let packages = jdata{"packages"}.getBool()
    let yes = jdata{"yes"}.getBool()

    var tstring = ""

    if rcfile.len != 0: bashrcpath = rcfile # Use provided path.

    if dirExists(ncliacdir) and not (force or update):
        tstring = "$1 exists. Setup with $2 to overwrite directory."
        quit(tstring % [ncliacdir.chalk("bold"), "--force".chalk("bold")])

    # Create default rcfile if needed.
    if not fileExists(bashrcpath):
        writeFile(bashrcpath, "")
        const perm644 = { fpUserWrite, fpUserRead, fpGroupRead, fpOthersRead }
        os.setFilePermissions(bashrcpath, perm644)

    createDir(registrypath)
    createDir(acmapssource)

    proc input(question, default: string = ""): string =
        echo question
        result = readLine(stdin)
        if result.len == 0: result = default

    var res = readFile(bashrcpath)
    if not res.contains(re("^ncliac=~", {reMultiLine})):
        var answer = ""
        var modrcfile = false
        if not yes:
            # Ask user whether to add nodecliac to rcfile.
            let chomedir = bashrcpath.replace(re("^" & hdir), "~")
            echo "Prompt".chalk("bold", "magenta") & " For nodecliac to work it needs to be added to your rcfile."
            echo "    ... The following line will be appended to " & chomedir.chalk("bold") & ":"
            echo "    ... " & """ncliac=~/.nodecliac/src/main/init.sh; [ -f "$ncliac" ] && . "\$ncliac";""".chalk("italic")
            echo "    ... (if skipping, manually add it after install to use nodecliac)"
            # [https://www.codecademy.com/articles/getting-user-input-in-node-js]
            answer = input("Answer".chalk("bold", "magenta") & ": [Press enter for default: Yes] " & "Add nodecliac to rcfile?".chalk("bold") & " [Y/n] ")
            if match(answer, re"^[Yy]"): modrcfile = true

            # Remove question/answer lines.
            discard execCmd("tput cuu 1 && tput el;".repeat(5))

        if answer.len == 0 or yes: modrcfile = true

        if modrcfile:
            res.stripLineEnd() # Remove trailing newlines.
            tstring = """?\nncliac=~/.nodecliac/src/main/?; [ -f "$ncliac" ] && . "$ncliac";"""
            writeFile(bashrcpath, tstring % [res, mainscriptname])

    # Create setup info file to reference on uninstall.
    let data = newJObject()
    data.add("force", newJBool(force or false))
    data.add("rcfile", newJString(bashrcpath))
    data.add("time", newJString($(getTime().toUnix())))
    let version = parseFile("../../../../../package.json")["version"].getStr()
    data.add("version", newJString(version))
    writeFile(setupfilepath, $data)

    var files = toOrderedSet([
        "ac/ac.pl",
        "ac/ac_debug.pl",
        "ac/utils",
        "ac/utils/LCP.pm",
        "bin/ac.linux",
        "bin/ac_debug.linux",
        "main/config.pl",
        "main/init.sh"
    ])
    if platform() == "darwin":
        let list = ["ac", "ac_debug"]
        for name in list:
            files.excl(fmt"bin/{name}.linux")
            files.incl(fmt"bin/{name}.macosx")
    let mainpath = joinPath(acmapssource, "main")

    # Remove comments from '#' comments from files.
    proc transform(source, dest: string) =
        writeFile(dest, strip_comments(readFile(source)))

    const perm775 = { # 775 permissions
        fpUserExec, fpUserWrite, fpUserRead, fpGroupExec,
        fpGroupWrite, fpGroupRead, fpOthersExec, fpOthersRead }
    # Ensure script files are executable.
    #
    # @param  {object} op - The files CopyOperation object.
    # @return {undefined} - Nothing is returned.
    proc cmode(path: string) = os.setFilePermissions(path, perm775)

    # If flag isn't provided don't install packages except nodecliac.
    if not packages:
        resourcespath = joinPath(resourcespath, "nodecliac")
        registrypath = joinPath(registrypath, "nodecliac")

    # Copy completion packages.
    const EXTS1 = [".sh", ".pl", ".nim"]
    for path in walkDirRec(resourcessrcs):
        if "/." in path: continue # Skip hidden files/dirs.
        let (dirname, filename) = splitPath(path)
        let lparent = lastPathPart(dirname)
        let filepath = joinPath(lparent, filename)
        if not files.contains(filepath): continue
        let ext = splitFile(filepath).ext
        let dest = joinPath(acmapssource, filepath)
        if ext in EXTS1: transform(path, dest)
        else: copyFile(path, dest)
        cmode(dest)

    # Copy nodecliac.sh test file.
    const EXTS2 = [".sh"]
    const ALLOWED = ["nodecliac.sh"]
    for path in walkDirRec(testsrcpath):
        if "/." in path: continue # Skip hidden files/dirs.
        let filename = splitPath(path).tail
        if filename notin ALLOWED: continue
        let ext = splitFile(filename).ext
        let dest = joinPath(mainpath, filename)
        if ext in EXTS2:
            writeFile(dest, strip_comments(readFile(path)))
        else: copyFile(path, dest)
        cmode(dest)

    # Copy nodecliac command packages/files to nodecliac registry.
    const EXTS3 = [".sh", ".pl"]
    for path in walkDirRec(resourcespath):
        if "/." in path: continue # Skip hidden files/dirs.
        let (dirname, filename) = splitPath(path)
        let lparent = lastPathPart(dirname)
        let filepath = joinPath(lparent, filename)
        if lparent == "packages": continue
        let ext = splitFile(filepath).ext
        let dest = joinPath(registrypath, filepath)
        if ext in EXTS3: transform(path, dest)
        else: copyFile(path, dest)
        cmode(dest)

    echo "Setup successful.".chalk("green")
