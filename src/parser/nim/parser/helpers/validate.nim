from re import re
from strutils import join, find, strip, startsWith
from tables import toTable, hasKey, initTable, `[]=`, `[]`, `$`

import error
from types import State, Node, Branch
from charsets import C_QUOTES, C_SPACES
from ../../utils/regex import findAllBounds
let r = re"(?<!\\)\$\{\s*[^}]*\s*\}"

# Validates string and interpolates its variables.
#
# @param  {object} S - State object.
# @param  {object} N - Node object.
# @return {object} - Object containing parsed information.
proc validate*(S: State, N: Node, `type`: string = ""): string =
    var value = N.value.value
    var `type` = `type`

    # If value doesn't exist or is '(' (long-form flag list) return.
    if value == "" or value == "(": return

    # Determine type if not provided.
    if `type` == "":
        `type` = "escaped"
        let `char` = value[0]
        if `char` == '$': `type` = "command-flag"
        elif `char` == '(': `type` = "list"
        elif `char` in C_QUOTES: `type` = "quoted"

    # Get column index to resume error checks at.
    var resumepoint = N.value.start - S.tables.linestarts[S.line]
    inc(resumepoint) # Add 1 to account for 0 base indexing.

    # Create temporary Node.
    #
    # @type {object} - The temp Node object.
    let tN = Node(value: Branch())

    # Set temporary Node.value values.
    #
    # @param  {number} start - The start index.
    # @param  {numbers} end - The end index.
    # @param  {string} val - The value.
    # @return - Nothing is returned.
    proc tNset(start: int, `end`: int, val: string) =
        let value = tN.value
        value.start = start
        value.`end` = `end`
        value.value = val

    case (`type`):
        of "quoted":
            let fchar = if value[0] == '$': value[1] else: value[0]
            let isquoted = fchar in C_QUOTES
            let lchar = value[^1]
            if isquoted:
                # Error if improperly quoted.
                if lchar != fchar:
                    S.column = resumepoint
                    error(S, currentSourcePath, 10)
                # Error it string is empty.
                if lchar == fchar and value.len == 2:
                    S.column = resumepoint
                    error(S, currentSourcePath, 11)

            # Interpolate variables.
            var bounds = findAllBounds(value, r)
            if bounds.len > 0:
                var action = S.args.action
                let vars = S.tables.variables
                for i in countdown(bounds.high, 0):
                    let bound = bounds[i]
                    let rp = value[bound.first .. bound.last][2 .. ^2].strip(trailing=true)

                    var sub = ""
                    if action == "make":
                        # Error if var is being used before declared.
                        if not vars.hasKey(rp):
                            S.column = resumepoint + bound.first
                            error(S, currentSourcePath, 12)
                        sub = vars[rp]
                    else: sub = "${" & rp & "}"
                    value[bound.first .. bound.last] = sub

            N.args = @[value]
            N.value.value = value

        of "escaped":
            N.args = @[value]
        of "command-flag":
            # Error if command-flag doesn't start with '$('.
            if not value.startsWith("$("):
                S.column = resumepoint + 1
                error(S, currentSourcePath, 13)
            # Error if command-flag doesn't end with ')'.
            if value[^1] != ')':
                S.column = resumepoint + value.high
                error(S, currentSourcePath, 13)

            var argument = ""
            var args: seq[string] = @[]
            var qchar: char
            var delimiter_count = 0
            var delimiter_index = -1
            var i = 2 # Offset to account for '$('.
            var resume_index = N.value.start + i
            var vsi: int # Index where value starts.

            # Ignore starting '$(' and ending ')' when looping.
            let l = value.high
            while i < l:
                let `char` = value[i]
                let pchar = if i - 0 > 0: value[i - 1] else: '\0'
                let nchar = if i + 1 < l: value[i + 1] else: '\0'

                if qchar == '\0':
                    # Look for unescaped quote characters.
                    if `char` in C_QUOTES and pchar != '\\':
                        vsi = resume_index
                        qchar = `char`
                        argument &= $`char`
                    elif `char` in C_SPACES: discard
                        # Ignore any whitespace outside of quotes.
                    elif `char` == ',':
                        # Track count of command delimiters.
                        inc(delimiter_count)
                        delimiter_index = i

                        # If delimiter count is >1, there are empty args.
                        if delimiter_count > 1 or args.len == 0:
                            S.column = resumepoint + i
                            error(S, currentSourcePath, 14)
                    # Look for '$' prefixed strings.
                    elif `char` == '$' and nchar in C_QUOTES:
                        qchar = nchar
                        argument &= $`char` & $nchar
                        inc(resume_index)
                        inc(i)
                        vsi = resume_index
                    else:
                        # Note: Anything else isn't allowed. For example,
                        # hitting this block means a character isn't
                        # being quoted. Something like this can trigger
                        # this block.
                        # Example: $("arg1", "arg2", arg3 )
                        # ---------------------------^ Value is unquoted.

                        S.column = resumepoint + i
                        error(S, currentSourcePath)
                else:
                    argument &= $`char`

                    if `char` == qchar and pchar != '\\':
                        tNset(vsi, argument.high, argument)
                        argument = validate(S, tN, "quoted")
                        args.add(argument)

                        argument = ""
                        qchar = '\0'
                        delimiter_index = -1
                        delimiter_count = 0

                inc(i); inc(resume_index)

            # If flag is still there is a trailing command delimiter.
            if delimiter_index > -1 and argument == "":
                S.column = resumepoint + delimiter_index
                error(S, currentSourcePath, 14)

            # Get last argument.
            if argument != "":
                dec(i) # Reduce to account for last completed iteration.

                tNset(vsi, argument.high, argument)
                argument = validate(S, tN, "quoted")
                args.add(argument)

            let cvalue = "$(" & args.join(",") & ")" # Build clean cmd-flag.
            N.args = @[cvalue]
            N.value.value = cvalue
            value = cvalue

        of "list":
            # Error if list doesn't start with '('.
            if value[0] != '(':
                S.column = resumepoint
                error(S, currentSourcePath, 15)
            # Error if command-flag doesn't end with ')'.
            if value[^1] != ')':
                S.column = resumepoint + value.high
                error(S, currentSourcePath, 15)

            var argument = ""
            var args: seq[string] = @[]
            var qchar: char
            var mode = ""
            var i = 1 # Offset to account for '('.
            var resume_index = N.value.start + i
            var vsi: int # Index where value starts.

            # Ignore starting '(' and ending ')' when looping.
            let l = value.high
            while i < l:
                let `char` = value[i]
                let pchar = if i - 0 > 0: value[i - 1] else: '\0'

                if mode == "":
                    # Skip unescaped ws delimiters.
                    if `char` in C_SPACES and pchar != '\\':
                        inc(i); inc(resume_index);
                        continue

                    # Set mode depending on the character.
                    if `char` in C_QUOTES and pchar != '\\':
                        vsi = resume_index
                        mode = "quoted"
                        qchar = `char`
                    elif `char` == '$' and pchar != '\\':
                        vsi = resume_index
                        mode = "command-flag"
                    elif `char` notin C_SPACES:
                        vsi = resume_index
                        mode = "escaped"
                    # All other characters are invalid so error.
                    else:
                        S.column = resumepoint + i
                        error(S, currentSourcePath)

                    # Note: If arguments array is already populated
                    # and if the previous `char` is not a space then
                    # the argument was not delimited so give an error.
                    # Example:
                    # subl.command = --flag=(1234 "ca"t"    $("cat"))
                    # --------------------------------^ Error point.
                    if args.len != 0 and pchar notin C_SPACES:
                        S.column = resumepoint + i
                        error(S, currentSourcePath)

                    argument &= $`char`
                elif mode != "":
                    if mode == "quoted":
                        # Stop at same-style quote char.
                        if `char` == qchar and pchar != '\\':
                            argument &= $`char`

                            let `end` = argument.high
                            tNset(vsi, `end`, argument)
                            argument = validate(S, tN, mode)
                            args.add(argument)

                            argument = ""
                            mode = ""
                            vsi = 0
                        else: argument &= $`char`
                    elif mode == "escaped":
                        # Stop at unescaped ws char.
                        if `char` in C_SPACES and pchar != '\\':
                            # argument &= $`char` # Store character.

                            let `end` = argument.high
                            tNset(vsi, `end`, argument)
                            argument = validate(S, tN, mode)
                            args.add(argument)

                            argument = ""
                            mode = ""
                            vsi = 0
                        else: argument &= $`char`
                    elif mode == "command-flag":
                        # Stop at unescaped ')' char.
                        if `char` == ')' and pchar != '\\':
                            argument &= $`char`

                            let `end` = argument.high
                            tNset(vsi, `end`, argument)
                            argument = validate(S, tN, mode)
                            args.add(argument)

                            argument = ""
                            mode = ""
                            vsi = 0
                        else: argument &= $`char`

                inc(i); inc(resume_index)

            # Get last argument.
            if argument != "":
                tNset(vsi, argument.high, argument)
                argument = validate(S, tN, mode)
                args.add(argument)

            N.args = args
            let cargs =  "(" & args.join(" ") & ")"
            N.value.value = cargs
            value = cargs

    return value