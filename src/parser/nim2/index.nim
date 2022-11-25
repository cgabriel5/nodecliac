import ./helpers/[types]
import std/[re, strutils, os, tables, strtabs]

import parser
import utils/[chalk, argvparse, exit, fs]

# Wrap code in a function:
# [https://forum.nim-lang.org/t/4835#30312]
# [https://forum.nim-lang.org/t/1268#7848]
# [https://forum.nim-lang.org/t/3788#23609]
proc main =
    let args = argvparse()
    let igc = args.igc
    let test = args.test
    let print = args.print
    let trace = args.trace
    let tokens = args.tokens
    let branches = args.branches
    let action = args.action
    var indent = args.indent
    var source = args.source
    let formatting = action == "format"

    var fmtinfo: tuple[char: char, amount: int]
    fmtinfo = (char: '\t', amount: 1)
    # Parse/validate indentation.
    if formatting and indent != "":
        let r = re"^(s|t):\d+$"
        if indent.find(r) == -1:
            echo "Invalid indentation string."
            exit()
        let components = indent.split(":", 2)
        fmtinfo.char = if components[0] == "s": ' ' else: '\t'
        fmtinfo.amount = components[1].parseInt()

    # Source must be provided.
    if source == "":
        echo "Please provide a " & "--source".chalk("bold") & " path."
        exit()

    # Breakdown path.
    let fi = info(source)
    let extension = fi.ext
    let cmdname = fi.name.replace(re("\\." & extension & "$")) # [TODO] `replace`
    let dirname = fi.dirname

    # Make path absolute.
    if not source.isAbsolute(): source = absolutePath(source)

    if dirExists(source):
        echo "Directory provided but .acmap file path needed."
        exit()
    if not fileExists(source):
        echo "Path " & source.chalk("bold") & " doesn't exist."
        exit()

    # [TODO] Look into why using `let` over `var` causes hang up when file
    # is large. Possibly due to `openFileStream`?
    var res = read(source); shallow(res)
    # let (
    #     acdef, config, keywords, filedirs,
    #     contexts, formatted, placeholders, tests
    # ) = parser(
    #     action, res, cmdname,
    #     source, fmtinfo, trace, igc, test
    # )

    let (
        acdef, config, keywords, filedirs,
        contexts, formatted, placeholders, tests
    ) = parser(
        action, res, cmdname,
        source, fmtinfo, trace, igc, test,
        tokens, branches
    )

    let testname = cmdname & ".tests.sh"
    let savename = cmdname & ".acdef"
    let saveconfigname = "." & cmdname & ".config.acdef"

    # Only save files to disk when not testing.
    if not test:
        if formatting: write(source, formatted)
        else:
            let testpath = joinPath(dirname, testname)
            let commandpath = joinPath(dirname, savename)
            let commandconfigpath = joinPath(dirname, saveconfigname)
            let placeholderspaths = joinPath(dirname, "placeholders")

            createDir(dirname)
            write(commandpath, acdef & keywords & filedirs & contexts)
            write(commandconfigpath, config)

            # Save test file if tests were provided.
            if tests != "":
                write(testpath, tests) # [https://forum.nim-lang.org/t/5270]
                os.setFilePermissions(testpath, { # 775 permissions
                    fpUserExec, fpUserWrite, fpUserRead, fpGroupExec,
                    fpGroupWrite, fpGroupRead, fpOthersExec, fpOthersRead
                }) # [https://stackoverflow.com/a/54638633]

            # Create placeholder files if object is populated.
            if placeholders.len > 0:
                createDir(placeholderspaths)

                for key in placeholders.keys:
                    let p = placeholderspaths & "/" & key
                    write(p, placeholders[key])

    if print:
        if not formatting:
            if acdef != "":
                echo "[" & (cmdname & ".acdef").chalk("bold") & "]\n"
                echo acdef & keywords & filedirs & contexts
                if config == "": echo ""
            if config != "":
                let msg = "\n[" & ("." & cmdname & ".config.acdef").chalk("bold") & "]\n"
                echo msg
                echo config & "\n"
        else: echo formatted

    # Test (--test) purposes.
    if test:
        if not formatting:
            if acdef != "":
                echo acdef & keywords & filedirs & contexts
                if config == "": echo ""
            if config != "":
                if acdef != "": echo ""
                echo config
        else: echo formatted

main()
