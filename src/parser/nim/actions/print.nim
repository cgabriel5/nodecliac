proc print() {.async.} =
    var tstring = ""

    # Source must be provided.
    if prcommand.len == 0:
        tstring = "Please provide a command name using the $1 flag."
        quit(tstring % ["--command".chalk("bold")])

    # If command is supplied then print its acdef/config file contents.
    if prcommand.len != 0:
        # Break apart command.
        var cmdname = ""
        if prcommand =~ re"^(.*?)(\.(acdef))?$": cmdname = matches[0]
        let ext = ".acdef"

        # Exit and give error if a command name not provided.
        if cmdname.len == 0:
            tstring = "Please provide a command name (i.e. --command=$1)."
            quit(tstring % ["nodecliac.acdef".chalk("bold")])

        # Check if command chain contains invalid characters.
        let INVALID_CHARS = {'^', '-', '.', '_', ':', '\\', '/'} + Letters + Digits
        if cmdname.find(INVALID_CHARS) != -1:
            # Loop over command chain to highlight invalid character.
            var chars: seq[string] = @[]
            var invalid_char_count = 0
            for i, `char` in cmdname:
                let `char` = cmdname[i]

                # If an invalid character highlight.
                if `char` in INVALID_CHARS:
                    chars.add(($`char`).chalk("bold", "red"))
                    inc(invalid_char_count)
                else: chars.add($`char`)

            # Plural output character string.
            let char_string = "character" & (if invalid_char_count > 1: "s" else: "")

            # Invalid escaped command-flag found.
            let varg1 = "Invalid:".chalk("bold")
            let varg3 = chars.join("")
            quit("$1 $2 in command: $3" % [varg1, char_string, varg3])

        # File paths.
        let pathstart = fmt"{registrypath}/{cmdname}"
        let filepath = fmt"{pathstart}/{cmdname}{ext}"
        let filepathconfig = fmt"{pathstart}/.{cmdname}.config{ext}"

        # Check if acdef file exists. Print file contents.
        if fileExists(filepath):
            # Log file contents.
            echo "\n" & fmt"{cmdname}{ext}".chalk("bold") & "\n"
            echo readFile(filepath)

            # Check if config file exists. Print file contents.
            if fileExists(filepathconfig):
                # Log file contents.
                let header = fmt".{cmdname}.config{ext}".chalk("bold")
                echo fmt"[{header}]\n"
                echo readFile(filepathconfig)
        else:
            # If acdef file does not exist log a message and exit script.
            let bcmdname = cmdname.chalk("bold")
            quit(fmt"acdef file for command {bcmdname} does not exist.")
