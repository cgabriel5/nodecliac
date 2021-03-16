from re import re, replacef
from strutils import join, strip, startsWith
from tables import `[]=`, `[]`, hasKey, OrderedTableRef, pairs

import error, vcontext, vtest
from types import State, Node, Branch
from charsets import C_QUOTES, C_SPACES, C_CTX_ALL, C_CTX_MUT,
    C_CTX_FLG, C_CTX_CON, C_LETTERS, C_CTX_CAT, C_CTX_OPS
from ../../utils/regex import findAllBounds
let r = re"(?<!\\)\$\{\s*[^}]*\s*\}"
let r_unescap = re"(?:\\(.))"

# Validates string and interpolates its variables.
#
# @param  {object} S - State object.
# @param  {object} N - Node object.
# @return {object} - Object containing parsed information.
proc validate*(S: State, N: Node, `type`: string = ""): string =
    var value = N.value.value
    let action = S.args.action
    let formatting = S.args.action == "format"
    var `type` = `type`

    # Get column index to resume error checks at.
    var resumepoint = N.value.start - S.tables.linestarts[S.line]
    inc(resumepoint) # Add 1 to account for 0 base indexing.

    # If validating a keyword there must be a value.
    if N.node == "FLAG" and N.keyword.value != "":
        let kw = N.keyword.value
        let ls = S.tables.linestarts[S.line]
        # Check for misused exclude.
        let sc = S.scopes.command
        if sc.node != "":
            if kw == "exclude" and sc.command.value != "*":
                S.column = N.keyword.start - ls
                inc(S.column) # Add 1 to account for 0 base indexing.
                error(S, currentSourcePath, 17)

        if value == "":
            S.column = N.keyword.`end` - S.tables.linestarts[S.line]
            inc(S.column) # Add 1 to account for 0 base indexing.
            error(S, currentSourcePath, 16)

        let C = if kw == "default": C_QUOTES + {'$'} else: C_QUOTES
        # context, filedir, exclude must have quoted string values.
        if value[0] notin C:
            S.column = resumepoint
            error(S, currentSourcePath)

    # If value doesn't exist or is '(' (long-form flag list) return.
    if value == "" or value == "(": return

    # Determine type if not provided.
    if `type` == "":
        `type` = "escaped"
        let `char` = value[0]
        if `char` == '$': `type` = "command-flag"
        elif `char` == '(': `type` = "list"
        elif `char` in C_QUOTES: `type` = "quoted"

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
            let schar = value[^2]
            if isquoted:
                # Error if improperly quoted/end quote is escaped.
                if lchar != fchar or schar == '\\':
                    S.column = resumepoint
                    error(S, currentSourcePath, 10)
                # Error it string is empty.
                if lchar == fchar and value.len == 2:
                    S.column = resumepoint
                    error(S, currentSourcePath, 11)

            # Interpolate variables.
            var bounds = findAllBounds(value, r)
            var vindices = OrderedTableRef[int, tuple[ind, sl: int]]()
            if bounds.len > 0:
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

                    # Calculate variable indices.
                    let sl = sub.len
                    let vl = (bound.last - bound.first) + 1
                    let dt = sl - vl
                    vindices[bound.first] = (ind: if sl > vl: dt * -1 else: abs(dt), sl: sl)

            # Validate context string.
            if not formatting and N.node == "FLAG" and
                N.keyword.value == "context":
                value = vcontext(S, value, vindices, resumepoint)
            # Validate test string.
            if not formatting and N.node == "SETTING" and
                N.name.value == "test":
                value = vtest(S, value, vindices, resumepoint);

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

            # Build clean cmd-flag and remove backslash escapes, but keep
            # escaped backslashes: [https://stackoverflow.com/a/57430306]
            # [TODO] Undo unescaping when formatting? (revisit this)
            let cvalue = ("$(" & args.join(",") & ")") #.replacef(r_unescap, "$1")
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
