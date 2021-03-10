import os, osproc, strutils, asyncdispatch, json, strformat

import ../utils/[chalk, paths, tilde]

proc nlcli_init*(s: string = "{}") {.async.} =
    let cwd = paths["cwd"]

    let jdata = parseJSON(s)
    let force = jdata{"force"}.getStr()
    # let disable = jdata{"disable"}.getStr()
    # var script = jdata{"script"}.getStr()

    proc main(restart: bool = false) {.async.} =
        if restart: echo ""

        echo "Info".chalk("bold", "blue") & " nodecliac completion package initialization."

        var command = ""
        const padding = ""
        let def = "default".chalk("italic", "bold", "cyan")
        let pprefix = padding & "Prompt:".chalk("bold", "magenta")
        let aprefix = padding & "Answer:".chalk("bold", "green")

        # Print reply/response.
        #
        # @param  {string} reply - The provided reply.
        # @return {undefined} - Nothing is returned.
        proc preply(reply: string) =
            echo aprefix & " " & reply.chalk("bold")

        proc input(question, default: string = ""): string =
            echo question
            result = readLine(stdin)
            if result.len == 0: result = default

        while command == "":
            command = input(fmt"{pprefix} [1/6] Completion package command (" & "required".chalk("yellow") & "): ")
            # Clear line on empty response.
            if command == "": discard execCmd("tput cuu 1 && tput el")
        command = command.strip()

        # Check for existing same name completion package.
        let pkgpath = joinPath(cwd, command)
        let spkgpath = shrink(pkgpath)
        if force.len == 0 and dirExists(pkgpath):
            echo "Error:".chalk("bold", "red") & " Directory ${chalk.bold(command)} already exists at:"
            echo fmt"... {spkgpath}"
            echo "(\"Tip:\")".chalk("bold", "blue") & " Run with --force flag to overwrite existing folder."
            quit()

        preply(command)
        let author = input(fmt"{pprefix} [2/6] Author (GitHub username or real name): ", "")
        preply(author)
        let version = input(fmt"{pprefix} [3/6] Version [{def} 0.0.1]: ", "0.0.1")
        preply(version)
        let des_def = "Completion package for {command}"
        let description = input(fmt"{pprefix} [4/6] Description [{def} {des_def}]: ", des_def)
        preply(description)
        let license = input(fmt"{pprefix} [5/6] Project license [{def} MIT]: ", "MIT")
        preply(license)
        let repo = input(fmt"{pprefix} [6/6] Github repo: (i.e. username/repository) ", "")
        preply(repo)

        let content = "[Package]".chalk("magenta") & fmt"""
name = "{command}"
version = "{version}"
description = "{description}"
license = "{license}"

""" & "[Author]".chalk("magenta") & fmt"""
name = "{author}"
repo = "{repo}""""

        echo ""
        echo "Info:".chalk("bold", "blue") & " package.ini will contain the following:"
        echo ""
        echo content

        echo ""
        echo "Info:".chalk("bold", "blue") & " Completion package base structure:`"
        echo ""
        let tree = fmt"""{spkgpath}
├── {command}.acmap
├── {command}.acdef
├── .{command}.config.acmap
└── package.ini"""
        echo tree
        echo ""

        var confirmation = ""
        let allowed = ["y", "yes", "c", "cancel", "n", "no", "r", "restart"]
        while confirmation.toLower() notin allowed:
            confirmation = input(
                "{pprefix} Looks good, create package? [" &
                "default".chalk("italic", "bold", "cyan") &
                " " &
                "y".chalk("bold", "cyan") & "]es, [c]ancel, [r]estart: ",
                "y"
            )
            # Clear line on empty response.
            if confirmation.toLower() notin allowed:
                discard execCmd("tput cuu 1 && tput el")

        confirmation = ($confirmation[0]).toLower()
        preply(confirmation)
        if confirmation == "y":
            # Create basic completion package for command.
            createDir(pkgpath)
            let pkginipath = joinPath(pkgpath, "package.ini")
            let acmappath = joinPath(pkgpath, fmt"{command}.acmap")
            let acdefpath = joinPath(pkgpath, fmt"${command}.acdef")
            let configpath = joinPath(pkgpath, fmt".{command}.config.acmap")

            const perm775 = { # 775 permissions
                fpUserExec, fpUserWrite, fpUserRead, fpGroupExec,
                fpGroupWrite, fpGroupRead, fpOthersExec, fpOthersRead
            } # [https://stackoverflow.com/a/54638633]

            writeFile(pkginipath, stripansi(content));
            os.setFilePermissions(pkginipath, perm775)
            writeFile(acmappath, ""); os.setFilePermissions(acmappath, perm775)
            writeFile(acdefpath, ""); os.setFilePermissions(acdefpath, perm775)
            writeFile(configpath, ""); os.setFilePermissions(configpath, perm775)
            echo ""
            echo "Info:".chalk("bold", "blue") & " completion packaged created at:"
            echo fmt"... {shrink(pkgpath)}"
        elif confirmation == "c":
            quit(fmt"\n" & "Info:".chalk("bold", "blue") & " Completion package initialization cancelled.")
        elif confirmation == "r": asyncCheck main(true)

    asyncCheck main()
