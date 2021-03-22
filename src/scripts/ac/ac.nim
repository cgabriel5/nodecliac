#!/usr/bin/env nim

import std/[
        os, streams, strformat, algorithm, osproc, re,
        sequtils, tables, strtabs, strutils
    ]

import utils/lcp

proc main() =

    if os.paramCount() == 0: quit()

    let oinput = os.paramStr(1) # Original unmodified CLI input.
    let cline = os.paramStr(2) # CLI input (could be modified via pre-parse).
    let cpoint = os.paramStr(3).parseInt(); # Caret index when [tab] key was pressed.
    let maincommand = os.paramStr(4) # Get command name from sourced passed-in argument.
    let acdef = os.paramStr(5) # Get the acdef definitions file.
    let posthook = os.paramStr(6) # Get the posthook file path.
    let singletons = parseBool(os.paramStr(7)) # Show singleton flags?

    var args: seq[string] = @[]
    var cargs: seq[string] = @[]
    var posargs: seq[string] = @[]
    var afcount = 0
    # Arguments meta data: [eq-sign index, isBool]
    var ameta: seq[array[2, int]] = @[]
    var last = ""
    var quote_open = false
    # Parsed last (flag) data.
    var dflag: tuple[flag: string, eq: char, value: string]
    var `type` = ""
    var completions: seq[string] = @[]
    var commandchain = ""
    var lastchar: char # Character before caret.
    let nextchar = cline.substr(cpoint, cpoint) # Character after caret.
    var cline_length = cline.len # Original input's length.
    var isquoted = false
    # var autocompletion = true
    var input = cline.substr(0, cpoint - 1) # CLI input from start to caret index.
    var input_remainder = cline.substr(cpoint, -1)# CLI input from caret index to input string end.
    let hdir = os.getEnv("HOME")
    let TESTMODE = os.getEnv("TESTMODE") == "1"
    var filedir = ""

    var db_dict = initTable[char, Table[string, Table[string, seq[string]]]]()
    var db_levels = initTable[int, Table[string, int]]()
    var db_defaults = newStringTable()
    var db_filedirs = newStringTable()
    var db_contexts = newStringTable()

    var usedflags = initTable[string, Table[string, int]]()
    var usedflags_valueless = initTable[string, int]()
    var usedflags_multi = initTable[string, int]()
    var usedflags_counts = initTable[string, int]()

    var used_default_pa_args = ""
    const prefix = "NODECLIAC_"

    const C_QUOTES = {'"', '\''}
    const C_SPACES = {' ', '\t'}
    const C_QUOTEMETA = Letters + Digits + {'_'}
    const C_VALID_CMD = Letters + Digits + {'-', '.', '_', ':', '\\'}
    const C_VALID_FLG = Letters + Digits + {'-', '_', }

    # --------------------------------------------------------- VALIDATION-FUNCTIONS

    # Peek string for '/','~'. If contained assume it's a file/dir.
    #
    # @param  {string} item - The string to check.
    # @return {bool}
    proc fn_is_file_or_dir(item: string): bool =
        return '/' in item or item == "~"

    # Escape '\' chars and replace unescaped slashes '/' with '.'.
    #
    # @param  {string} item - The item (command) string to escape.
    # @return {string} - The escaped item (command) string.
    proc fn_normalize_command(item: var string): string =
        if fn_is_file_or_dir(item): return item
        return item.replace(".", "\\\\.") # Escape periods.

    # Validates whether command/flag (--flag) only contain valid characters.
    #     Containing invalid chars exits script - terminating completion.
    #
    # @param  {string} item - The word to check.
    # @return {string} - The validated argument.
    proc fn_validate_flag(item: string): string =
        if fn_is_file_or_dir(item): return item
        if not allCharsInSet(item, C_VALID_FLG): quit()
        return item

    # Look at fn_validate_flag for details.
    proc fn_validate_command(item: string): string =
        if fn_is_file_or_dir(item): return item
        if not allCharsInSet(item, C_VALID_CMD): quit()
        return item

    # ------------------------------------------------------------- STRING-FUNCTIONS

    # Removes and return last char
    #
    # @param  {string} s - The string to modify.
    # @return {string} - The removed character.
    proc chop(s: var string): char =
        result = s[^1]
        s.setLen(s.high)

    # Removes and returns first char.
    #
    # @param  {string} s - The string to modify.
    # @param  {number} end - Optional end/cutoff index.
    # @return {char} - The removed character.
    proc shift(s: var string, `end`: int = 0): char =
        result = s[0]
        s.delete(0, `end`)

    # Removes first and last chars from string.
    #
    # @param  {string} s - The string to modify.
    # @return - Nothing is returned.
    proc unquote(s: var string) =
        s.delete(0, 0)
        s.setLen(s.high)

    # Splits string into an its individual characters.
    #
    # @param  {string} - The provided string to split.
    # @return {seq} - The seq of individual characters.
    # @resource [https://stackoverflow.com/a/51160075]
    proc splitchars(s: string): seq[char] =
        return mapIt(s, it)

    # Substitute for Perl's quotemeta function.
    #
    # @param  {string} s - The string to escape.
    # @return {string} - The escaped string.
    # @resource [https://perldoc.perl.org/functions/quotemeta.html]
    proc quotemeta(s: string): string =
        for c in s: result &= (if c notin C_QUOTEMETA: '\\' & c else: $c)

    # ------------------------------------------------------------------------------

    # Predefine procs to maintain proc order with ac.pl.
    proc parseCmdStr(input: var string): seq[string]
    proc setEnvs(arguments: varargs[string], post=false)

    # Parse and run command-flag (flag) or default command chain.
    #
    # @param  {string} - The command to run in string.
    # @return - Nothing is returned.
    #
    # Create cmd-string: `$command 2> /dev/null`
    # 'bash -c' with arguments documentation:
    # @resource [https://stackoverflow.com/q/26167803]
    # @resource [https://unix.stackexchange.com/a/144519]
    # @resource [https://stackoverflow.com/a/1711985]
    # @resource [https://stackoverflow.com/a/15678831]
    # @resource [https://stackoverflow.com/a/3374285]
    proc execCommand(command_str: var string): seq[string] =
        var arguments = parseCmdStr(command_str)
        let count = arguments.len
        var command = arguments[0]
        unquote(command)
        var delimiter = "\\r?\\n"
        var r: seq[string] = @[]

        if count > 1: # Add arguments.
            for i in countup(1, count - 1, 1):
                var arg = arguments[i]

                # Run '$' string.
                if arg.startsWith('$'):
                    discard shift(arg)
                    let qchar = arg[0]
                    unquote(arg)
                    # command &= " \"$(" & qchar & arg & qchar & ")\""
                    # Wrap command with ticks to target the common shell 'sh'.
                    command &= " " & qchar & "`" & arg & "`" & qchar
                else: command &= " " & arg

        setEnvs()
        var res = ""
        try: res = execProcess(command)
        except: discard
        result = if res != "": split(res, re(delimiter)) else: r

    # Parse command string `$("")` and returns its arguments.
    #
    # Syntax:
    # $("COMMAND-STRING" [, [<ARG1>, <ARGN> [, "<DELIMITER>"]]])
    #
    # @param  {string} input - The string command-flag to parse.
    # @return {string} - The cleaned command-flag string.
    proc parseCmdStr(input: var string): seq[string] =
        var argument = ""
        var args: seq[string] = @[]
        var qchar = '\0'
        var c, p: char

        if input == "": return args

        while input != "":
            c = shift(input)
            p = if argument.len > 0: argument[^1] else: '\0'

            if qchar == '\0':
                if c in C_QUOTES and p != '\\':
                    qchar = c
                    argument &= $c
                elif args.len > 1 and c == '$' and argument == "":
                    argument &= $c
            else:
                if c == '|' and p == '\\': discard chop(argument)
                argument &= $c

                if c == qchar and p != '\\':
                    args.add(argument)
                    argument = ""
                    qchar = '\0'

        if argument != "": args.add(argument)
        return args

    # Set environment variables to access in custom scripts.
    #
    # @param  {string} arguments - N amount of env names to set.
    # @return - Nothing is returned.
    proc setEnvs(arguments: varargs[string], post=false) =
        let l = args.len
        let ctype = (if `type`[0] == 'c': "command" else: "flag")
        let prev = args[^(if not post: 2 else: 1)]

        # Get any used flags to pass along.
        var usedflags: seq[string] = @[]
        for k in usedflags_counts.keys: usedflags.add(k)

        var envs = {
            # nodecliac exposed Bash env vars.

            fmt"{prefix}COMP_LINE": cline, # Original (unmodified) CLI input.
            # Caret index when [tab] key was pressed.
            fmt"{prefix}COMP_POINT": intToStr(cpoint),

            # nodecliac env vars.

            # The command auto completion is being performed for.
            fmt"{prefix}MAIN_COMMAND": maincommand,
            fmt"{prefix}COMMAND_CHAIN": commandchain, # The parsed command chain.
            fmt"{prefix}USED_FLAGS": usedflags.join("\n"), # The parsed used flags.
            # The last parsed word item (note: could be a partial word item.
            # This happens when the [tab] key gets pressed within a word item.
            # For example, take the input 'maincommand command'. If
            # the [tab] key was pressed like so: 'maincommand comm[tab]and' then
            # the last word item is 'comm' and it is a partial as its remaining
            # text is 'and'. This will result in using 'comm' to determine
            # possible auto completion word possibilities.).
            fmt"{prefix}LAST": last,
            # The word item preceding last word item.
            fmt"{prefix}PREV": prev,
            fmt"{prefix}INPUT": input, # CLI input from start to caret index.
            fmt"{prefix}INPUT_ORIGINAL": oinput, # Original unmodified CLI input.
            # CLI input from start to caret index.
            fmt"{prefix}INPUT_REMAINDER": input_remainder,
            fmt"{prefix}LAST_CHAR": $lastchar, # Character before caret.
            # Character after caret. If char is not '' (empty) then the last word
            # item is a partial word.
            fmt"{prefix}NEXT_CHAR": nextchar,
            # Original input's length.
            fmt"{prefix}COMP_LINE_LENGTH": intToStr(cline_length),
            # CLI input length from beginning of string to caret position.
            fmt"{prefix}INPUT_LINE_LENGTH": intToStr(input.len),
            # Amount arguments parsed before caret position/index.
            fmt"{prefix}ARG_COUNT": intToStr(l),
            # Store collected positional arguments after validating the
            # command-chain to access in plugin auto-completion scripts.
            fmt"{prefix}USED_DEFAULT_POSITIONAL_ARGS": used_default_pa_args,
            # Whether completion is being done for a command or a flag.
            fmt"{prefix}COMP_TYPE": ctype
        }.toTable

        # If completion is for a flag, set flag data for quick access in script.
        if ctype == "flag":
            envs[fmt"{prefix}FLAG_NAME"] = dflag.flag
            envs[fmt"{prefix}FLAG_EQSIGN"] = $dflag.eq
            envs[fmt"{prefix}FLAG_VALUE"] = dflag.value
            # Indicates if last word is an open quoted value.
            envs[fmt"{prefix}QUOTE_OPEN"] = if quote_open: "1" else: "0"

        # Set completion index (index where completion is being attempted) to
        # better mimic bash's $COMP_CWORD builtin variable.
        let comp_index = if lastchar == '\0' or
            (last.len > 0 and (
                last[0] in C_QUOTES or quote_open or last[^2] == '\\'
            )): $(l - 1) else: $l
        envs[fmt"{prefix}COMP_INDEX"] = comp_index
        # Also, ensure NODECLIAC_PREV is reset to the second last argument
        # if it exists only when the lastchar is empty to To better mimic
        # prev=${COMP_WORDS[COMP_CWORD-1]}.
        if lastchar == '\0' and l > l - 2: envs[fmt"{prefix}PREV"] = args[l - 2]

        # Add parsed arguments as individual env variables.
        for i, arg in args: envs[fmt"{prefix}ARG_{i}"] = arg

        # Set all env variables.
        if arguments.len == 0:
            for key, value in envs: os.putEnv(key, value)
        else: # Set requested ones only.
            for env_name in arguments:
                var key = prefix & env_name
                if envs.hasKey(key): os.putEnv(key, envs[key])

    # --------------------------------------------------------------- MAIN-FUNCTIONS

    # Parses CLI input.
    #
    # @return - Nothing is returned.
    proc fn_tokenize() =
        var argument = ""
        var qchar: char
        var input = input
        var delindex = -1
        var c, p: char

        if input == "": return

        # [TODO]: Re-do spread function; needs to be simplified/robust.

        # Spreads input, ex: '-n5 -abc "val"' => '-n 5 -a -b -c "val"'
        #
        # @param  {string} argument - The string to spread.
        # @return {string} - The remaining argument.
        proc spread(argument: var string): string =
            if argument.len >= 3 and argument[1] != '-' and '=' notin argument:
                discard shift(argument)
                let lchar = argument[^1]

                if lchar in "1234567890":
                    let argletter = argument[0]
                    discard shift(argument)
                    ameta.add([delindex, 0]); delindex = -1
                    args.add(fmt"-{argletter}")
                else:
                    let chars = splitchars(argument)
                    let max = chars.high
                    var i = 0
                    var hyphenref = false
                    for chr in chars:
                        # Handle: 'sudo wget -qO- https://foo.sh':
                        # Hitting a hyphen breaks loop. All characters at hyphen
                        # and beyond are now the value of the last argument.
                        if chr == '-': hyphenref = true; break

                        # Note: If the argument is not a hyphen and is the last
                        # item in the array, remove it from the array as it will
                        # get added back later in the main loop.
                        elif i == max: break

                        ameta.add([delindex, 0]); delindex = -1
                        args.add(fmt"-{chr}"); inc(i)

                    # Reset value to final argument.
                    argument = if not hyphenref: fmt"-{lchar}" else: argument.substr(i)

            return argument

        while input != "":
            c = shift(input)
            p = if argument.len > 0: argument[^1] else: '\0'

            if qchar != '\0':
                argument &= $c

                if c == qchar and p != '\\':
                    # Note: Check that argument is spaced out. For example, this
                    # is invalid: '$ nodecliac format --indent="t:1"--sa'
                    # ----------------------------------------------^. Should be:
                    #          '$ nodecliac format --indent="t:1" --sa'
                    # -------------------------------------------^Whitespace char.
                    # If argument is not spaced out or at the end of the input
                    # do not add it to the array. Just skip to next iteration.
                    # if input != "" and not input.startsWith(' '): continue

                    ameta.add([delindex, 0]); delindex = -1
                    args.add(if not argument.startsWith('-'): argument else: spread(argument))
                    argument = ""
                    qchar = '\0'

            else:
                if c in C_QUOTES and p != '\\':
                    qchar = c
                    argument &= $c

                elif c in C_SPACES and p != '\\':
                    if argument == "": continue

                    ameta.add([delindex, 0]); delindex = -1
                    args.add(if not argument.startsWith('-'): argument else: spread(argument))
                    argument = ""
                    qchar = '\0'

                else:
                    if c in "=:" and delindex == -1 and argument.len > 0 and argument.startsWith('-'):
                        delindex = argument.len
                        c = '=' # Normalize ':' to '='.
                    argument &= $c

        # If the qchar is set, there was an unclosed string like:
        # '$ op list itema --categories="Outdoor '
        if qchar != '\0': quote_open = true

        # Get last argument.
        if argument != "":
            ameta.add([delindex, 0]); delindex = -1
            args.add(if not argument.startsWith('-'): argument else: spread(argument))

        # Get last char of input.
        lastchar = if not (c != ' ' and p != '\\'): c else: '\0'

    # Wrapper for builtin cmp function. This function returns a boolean.
    #
    # @param  {string} a - The first string.
    # @param  {string} b - The second string.
    # @return {boolean} - Whether strings are the same or not.
    proc eq(a, b: string): bool = cmp(a, b) == 0

    # Determine command chain, used flags, and set needed variables.
    #
    # @return - Nothing is returned.
    proc fn_analyze() =
        let l = args.len
        var commands = ""
        var chainstring = " "
        var bound = 0

        proc trackflagcount(flag: string) =
            # Track times flag was used.
            if flag.len != 0 and (not eq(flag, "--") or not eq(flag, "-")):
                if flag notin usedflags_counts:
                    usedflags_counts[flag] = 0
                inc(usedflags_counts[flag])

        proc trackusedflag(flag, value: string) =
            if flag notin usedflags:
                usedflags[flag] = {value: 1}.toTable

        proc trackvaluelessflag(flag: string) = usedflags_valueless[flag] = 1

        var i = 1; while i < l:
            var item = args[i]
            let nitem = if i + 1 < l: args[i + 1] else: ""

            # # Skip quoted or escaped items.
            # if item[0] in C_QUOTES or '\\' in item:
            #     posargs.add(item)
            #     cargs.add(item)
            #     inc(i)
            #     continue

            if not item.startsWith('-'):
                let command = fn_normalize_command(item)
                var chain = commands & "." & command

                let (start, stop) = acdef.findBounds(re(
                    "^" & quotemeta(chain) & "[^ ]* ", {reMultiLine}))
                if start != -1:
                    chainstring = acdef[start .. stop]
                    bound = stop
                    commands &= "." & command
                else: posargs.add(item)

                cargs.add(item)

            else:
                inc(afcount) # Increment flag counter.

                if ameta[i][0] > -1:
                    cargs.add(item)

                    let flag = item[0 .. ameta[i][0] - 1]
                    let value = item[ameta[i][0] .. item.high]
                    trackusedflag(flag, value)
                    trackflagcount(flag)

                    inc(i); continue

                let flag = fn_validate_flag(item)
                let (start, stop) = findBounds(acdef, re(
                    "^" & quotemeta(chainstring) & "(.+)$", {reMultiLine}), start=bound)

                if acdef.rfind(flag & "?", start, last = stop) > 0:
                    cargs.add(flag)
                    ameta[i][1] = 1
                    trackvaluelessflag(flag)

                else:
                    if nitem != "" and not nitem.startsWith('-'):
                        let vitem = flag & "=" & nitem
                        cargs.add(vitem)
                        ameta[i][0] = flag.len

                        trackusedflag(flag, nitem)

                        inc(i)
                    else:
                        cargs.add(flag)
                        trackvaluelessflag(flag)

                trackflagcount(flag)

            inc(i)

        # Set needed data: cc, pos args, last word, and found flags.

        commandchain = fn_validate_command(commands)

        if posargs.len > 0: used_default_pa_args = posargs.join("\n")

        last = if lastchar == ' ': "" else: cargs[^1]
        # Reset if completion is being attempted for a quoted/escaped string.
        if lastchar == ' ' and cargs.len > 0:
            let litem = cargs[^1]
            quote_open = quote_open and litem[0] == '-'
            if (litem[0] in C_QUOTES or quote_open or litem[^2] == '\\'): last = litem
        if last.find(C_QUOTES) == 0: isquoted = true

        # Handle case: 'nodecliac print --command [TAB]'
        # if last == "" and cargs.len > 0 and cargs[^1].startsWith('-') and
        # ameta[^1][0] == -1 and ameta[^1][1] == 0:
        if last == "" and cargs.len > 0 and cargs[^1].startsWith('-') and
        '=' notin cargs[^1] and ameta[^1] == [-1, 0]:
            let r = cargs[^1] & "="
            lastchar = '\0'
            last = r
            cargs[^1] = r
            args[^1] = r
            ameta[^1][0] = r.high # Not needed?

    # Lookup acdef definitions.
    #
    # @return - Nothing is returned.
    proc fn_lookup(): string =
        # if isquoted or not autocompletion: return ""

        if last.startsWith('-'):
            `type` = "flag"

            var letter = if commandchain != "": commandchain[1] else: '_'
            commandchain = if commandchain != "": commandchain else: "_"
            if db_dict.hasKey(letter) and db_dict[letter].hasKey(commandchain):
                var excluded = initTable[string, int]()
                var parsedflags = initTable[string, int]()
                var flag_list = db_dict[letter][commandchain]["flags"][0]

                # If a placeholder get its contents.
                if flag_list =~ re"^--p#(.{6})$":
                    let strm = newFileStream(fmt"{hdir}/.nodecliac/registry/{maincommand}/placeholders/{matches[0]}", fmRead)
                    flag_list = strm.readAll()
                    strm.close()

                if flag_list == "--":  return ""

                # Split by unescaped pipe '|' characters:
                var flags = flag_list.split(re"(?<!\\)\|")

                # Context string logic: start --------------------------------------

                let cchain = if commandchain == "_": "" else: quotemeta(commandchain)
                let pattern = "^" & cchain & " context (.+)$"
                let (start, `end`) = findBounds(acdef, re(pattern, {reMultiLine}))
                if start != -1:
                    let row = acdef[start .. `end`]
                    let kw_index = row.find("context")
                    let sp_index = row.find(' ', start=kw_index)
                    let context = row[sp_index + 2 .. row.high - 1] # Unquote.

                    let ctxs = context.split(';')
                    for ctx in ctxs:
                        var ctx = ctx.multiReplace([(" ", ""), ("\t", "")])
                        if ctx.len == 0: continue
                        if ctx[0] == '{' and ctx[^1] == '}': # Mutual exclusion.
                            ctx = ctx.strip(chars={'{', '}'})
                            let flags = map(ctx.split('|'), proc (x: string): string =
                                (if x.len == 1: "-" else: "--") & x
                            )
                            var exclude = ""
                            for flag in flags:
                                if usedflags_counts.hasKey(flag):
                                    exclude = flag
                                    break
                            if exclude != "":
                                for flag in flags:
                                    if exclude != flag: excluded[flag] = 1
                                excluded.del(exclude)
                        else:
                            var r = false
                            if ':' in ctx:
                                let parts = ctx.split(':')
                                let flags = parts[0].split(',')
                                let conditions = parts[1].split(',')
                                # Examples:
                                # flags:      !help,!version
                                # conditions: #fge1, #ale4, !#fge0, !flag-name
                                # [TODO?] index-conditions: 1follow, 1!follow
                                for condition in conditions:
                                    var invert = false
                                    var condition = condition
                                    # Check for inversion.
                                    if condition[0] == '!':
                                        discard shift(condition)
                                        invert = true

                                    let fchar = condition[0]
                                    if fchar == '#':
                                        let operator = condition[2 .. 3]
                                        let n = condition[4 .. ^1].parseInt()
                                        var c = 0
                                        if condition[1] == 'f':
                                            c = usedflags_counts.len
                                            # Account for used '--' flag.
                                            if c == 1 and usedflags_counts.hasKey("--"): c = 0
                                            if lastchar == '\0': dec(c)
                                        else: c = posargs.len
                                        case (operator):
                                            of "eq": r = if c == n: true else: false
                                            of "ne": r = if c != n: true else: false
                                            of "gt": r = if c >  n: true else: false
                                            of "ge": r = if c >= n: true else: false
                                            of "lt": r = if c <  n: true else: false
                                            of "le": r = if c <= n: true else: false
                                            else: discard
                                        if invert: r = not r
                                    # elif fchar in {'1'..'9'}: continue # [TODO?]
                                    else: # Just a flag name.
                                        if fchar == '!':
                                            if usedflags_counts.hasKey(condition): r = false
                                        else:
                                            if usedflags_counts.hasKey(condition): r = true
                                    # Once any condition fails exit loop.
                                    if r == false: break
                                if r == true:
                                    for flag in flags:
                                        var flag = flag
                                        let fchar = flag[0]
                                        flag = flag.strip(chars={'!'})
                                        flag = (if flag.len == 1: "-" else: "--") & flag
                                        if fchar == '!': excluded[flag] = 1
                                        else: excluded.del(flag)
                            else: # Just a flag name.
                                if ctx[0] == '!':
                                    if usedflags_counts.hasKey(ctx): r = false
                                else:
                                    if usedflags_counts.hasKey(ctx): r = true
                                if r == true:
                                    var flag = ctx
                                    let fchar = flag[0]
                                    flag = flag.strip(chars={'!'})
                                    flag = (if flag.len == 1: "-" else: "--") & flag
                                    if fchar == '!': excluded[flag] = 1
                                    else: excluded.del(flag)

                # Context string logic: end ----------------------------------------

                var last_fkey = last
                var last_eqsign: char
                # var last_multif = ""
                var last_value = ""

                if '=' in last_fkey:
                    let eqsign_index = last.find('=')
                    last_fkey = last.substr(0, eqsign_index - 1)
                    last_value = last.substr(eqsign_index + 1)

                    if last_value.startsWith('*'):
                        # last_multif = "*"
                        last_value = last_value[0 .. ^2]

                    last_eqsign = '='

                let last_val_quoted = last_value.find(C_QUOTES) == 0

                # Store data for env variables.
                dflag = (flag: last_fkey, eq: last_eqsign, value: last_value)

                # Process flags.
                var i = 0; while i < flags.len:
                    let flag = flags[i]

                    if not flag.startsWith(last_fkey): inc(i); continue

                    var flag_fkey = flag
                    var flag_isbool: char
                    var flag_eqsign: char
                    var flag_multif: char
                    var flag_value = ""
                    var cflag = ""

                    # If flag contains an eq sign.
                    if '=' in flag_fkey:
                        var eqsign_index = flag.find('=')
                        flag_fkey = flag.substr(0, eqsign_index - 1)
                        flag_value = flag.substr(eqsign_index + 1)
                        flag_eqsign = '='

                        if '?' in flag_fkey: flag_isbool = chop(flag_fkey)
                        # Skip flag if it's mutually exclusivity.
                        if excluded.hasKey(flag_fkey): inc(i); continue

                        if flag_value.startsWith('*'):
                            flag_multif = '*'
                            flag_value = flag_value[0 .. ^2]

                            # Track multi-starred flags.
                            usedflags_multi[flag_fkey] = 1

                        # Create completion flag item.
                        cflag = fmt"{flag_fkey}={flag_value}"

                        # If a command-flag, run it and add items to array.
                        if flag_value.startsWith("$(") and flag_value.endsWith(')') and last_eqsign == '=':
                            `type` = "flag;nocache"
                            let lines = execCommand(flag_value)
                            for line in lines:
                                if line != "": flags.add(last_fkey & "=" & line)
                            # Don't add literal command to completions.
                            inc(i)
                            continue

                        # Store for later checks.
                        parsedflags[fmt"{flag_fkey}={flag_value}"] = 1
                    else:
                        if '?' in flag_fkey: flag_isbool = chop(flag_fkey)
                        # Skip flag if it's mutually exclusivity.
                        if excluded.hasKey(flag_fkey): inc(i); continue

                        # Create completion flag item.
                        cflag = flag_fkey
                        # Store for later checks.
                        parsedflags[flag_fkey] = 1

                    # If the last flag/word does not have an eq-sign, skip flags
                    # with values as it's pointless to parse them. Basically, if
                    # the last word is not in the form "--form= + a character",
                    # don't show flags with values (--flag=value).
                    if last_eqsign == '\0' and flag_value != "" and flag_multif == '\0':
                        inc(i)
                        continue

                    # [Start] Remove duplicate flag logic --------------------------

                    var dupe = 0

                    # Let multi-flags through.
                    if usedflags_multi.hasKey(flag_fkey):

                        # Check if multi-starred flag value has been used.
                        if flag_value != "":
                            # Add flag to usedflags root level.
                            if not usedflags.hasKey(flag_fkey):
                                usedflags[flag_fkey] = initTable[string, int]()
                            if usedflags[flag_fkey].hasKey(flag_value):
                                dupe = 1

                    elif flag_eqsign == '\0':

                        # Valueless --flag (no-value) dupe check.
                        if usedflags_valueless.hasKey(flag_fkey) or
                        # Check if flag was used with a value already.
                            (usedflags.hasKey(flag_fkey) and
                            usedflags_counts[flag_fkey] < 2 and
                            lastchar == '\0'): dupe = 1

                    else: # --flag=<value> (with value) dupe check.

                        # If usedflags contains <flag:value> at root level.
                        if usedflags.hasKey(flag_fkey):
                            # If no values exists.
                            if flag_value == "": dupe = 1 # subl -n 2, subl -n 23

                            else:
                                # Add flag to usedflags root level.
                                if not usedflags.hasKey(flag_fkey):
                                    usedflags[flag_fkey] = initTable[string, int]()
                                if usedflags[flag_fkey].hasKey(flag_value):
                                    dupe = 1 # subl -n 23 -n
                                elif usedflags_counts.hasKey(flag_fkey):
                                    if usedflags_counts[flag_fkey] > 1: dupe = 1

                        # If no root level entry.
                        else:
                            if last != flag_fkey and usedflags_valueless.hasKey(flag_fkey):
                                # Add flag to usedflags root level.
                                if not usedflags.hasKey(flag_fkey):
                                    usedflags[flag_fkey] = initTable[string, int]()
                                if not usedflags[flag_fkey].hasKey(flag_value):
                                    dupe = 1 # subl --type=, subl --type= --

                    if dupe == 1: inc(i); continue # Skip if dupe.

                    # [End] Remove duplicate flag logic ----------------------------

                    # Note: Don't list single letter flags. Listing them along
                    # with double hyphen flags is awkward. Therefore, only list
                    # them when completing or showing its value(s).
                    # [https://scripter.co/notes/nim/#from-string]
                    if not singletons and flag_fkey.len == 2 and flag_value == "":
                        inc(i); continue

                    # If last word is in the form '--flag=', remove the last
                    # word from the flag to only return its option/value.
                    if last_eqsign != '\0':
                        if not flag_value.startsWith(last_value) or flag_value == "": inc(i); continue
                        cflag = flag_value

                    # Don't add multi-starred flag item as its non-starred
                    # counterpart has already been added.
                    if flag_multif != '\0': inc(i); continue

                    completions.add(cflag)

                    inc(i)

                # Account for quoted strings. Add trailing quote if needed.
                if last_val_quoted:
                    let quote = last_value[0]
                    if last_value[^1] != quote: last_value &= $quote

                    # Add quoted indicator to later escape double quoted strings.
                    `type` = "flag;quoted"
                    if quote == '\"': `type` &= ";noescape"

                    # If value is empty return.
                    if last_value.len == 2:
                        completions.add($quote & $quote)
                        return ""

                # If no completions, add last item so Bash compl. can add a space.
                if completions.len == 0:
                    let key = last_fkey & (if last_value == "": "" else: "=" & last_value)
                    let item = if last_value == "": last else: last_value
                    if parsedflags.hasKey(key) and (last_value != "" or not last.endsWith('=')):
                        completions.add(item)
                else:
                    # Note: If the last word (the flag in this case) is an options
                    # flag (i.e. --flag=val) we need to remove the possibly already
                    # used value. For example take the following scenario. Say we
                    # are completing the following flag '--flag=7' and our two
                    # options are '7' and '77'. Since '7' is already used we remove
                    # that value to leave '77' so that on the next tab it can be
                    # completed to '--flag=77'.
                    if last_value != "" and completions.len >= 2:
                        var last_val_length = last_value.len
                        # Remove values same length as current value.
                        completions = filter(completions, proc (x: string): bool =
                            x.len != last_val_length
                        )

        else:

            `type` = "command"

            # # If command chain and used flags exits, don't complete.
            # if usedflags.len > 0 and commandchain != "":
            #     commandchain = if last == "": "" else: last

            # If no cc get first level commands.
            if commandchain == "" and last == "":
                if posargs.len == 0:
                    if db_levels.hasKey(1): completions = toSeq(db_levels[1].keys)
            else:
                let letter = if commandchain != "": commandchain[1] else: '_'
                # Letter must exist in dictionary.
                if not db_dict.hasKey(letter): return ""
                var rows = toSeq(db_dict[letter].keys)
                let lastchar_notspace = lastchar != ' '

                if rows.len == 0: return ""

                # When there is only 1 completion item and it's the last command
                # in the command chain, clear the completions array to not re-add
                # the same command.
                # if (rows.len == 1 and commandchain.endsWith(rows[0])): rows.setLen(0)

                var usedcommands = initTable[string, int]()
                var commands = (commandchain).split(re"(?<!\\)\.")
                var level = commands.len - 1
                # Increment level if completing a new command level.
                if lastchar == ' ': inc(level)

                # If level does not match argument length, return. As the
                # parsed arguments do not match that of a valid commandchain.
                let la = (cargs.len + 1) - afcount
                if not ((la == level + 1 and lastchar != '\0') or
                    (la > level and lastchar != '\0') or (la - level > 1)):

                    # Get commandchains for specific letter outside of loop.
                    var h = db_dict[letter]

                    for row in rows:
                        var row = row
                        # Command must exist.
                        if not h[row].hasKey("commands"): continue

                        var cmds = h[row]["commands"]
                        row = if level < cmds.len: cmds[level] else: ""

                        # Add last command if not yet already added.
                        if row == "" or usedcommands.hasKey(row): continue
                        # If char before caret isn't a space, completing a command.
                        if lastchar_notspace:
                            if row.startsWith(last):
                                let c = commandchain.endsWith("." & row)
                                if (not c or (c and lastchar == '\0')) or
                                used_default_pa_args == "" and lastchar == '\0':
                                    completions.add(row)
                        else: completions.add(row) # Allow all.

                        usedcommands[row] = 1

            # Note: If only 1 completion exists, check if command exists in
            # commandchain. If so, it's already used so clear completions.
            if nextchar != "" and completions.len == 1:
                var pattern = "." & completions[0] & "(\\.|$)"
                if contains(commandchain, re(pattern)): completions.setLen(0)

            # Run default command if no completions were found.
            if completions.len == 0:
                var copy_commandchain = commandchain
                let pattern = re"\.((?:\\\.)|[^\.])+$" # ((?:\\\.)|[^\.]*?)*$

                # Loop over command chains to build individual chain levels.
                while copy_commandchain != "":
                    # Get command-string, parse and run it.
                    var command_str = db_defaults.getOrDefault(copy_commandchain, "")
                    if command_str != "":
                        var lchar = chop(command_str)

                        # Run command string.
                        if command_str.startsWith("$(") and lchar == ')':
                            discard shift(command_str, 1)
                            let lines = execCommand(command_str)
                            for line in lines:
                                if line != "":
                                    if last != "":
                                        # Must start with command.
                                        if line.startsWith(last): completions.add(line)
                                    else:
                                        if line.startsWith('!'): continue
                                        completions.add(line)

                            # If no completions and last word is a valid completion
                            # item, add it to completions to add a trailing space.
                            if completions.len == 0:
                                var pattern = "^\\!?" & quotemeta(last) & "$"
                                let bounds = findBounds(lines.join("\n"), re(pattern, {reMultiLine}))
                                if bounds.first != -1: completions.add(last)

                        # Static value.
                        else:
                            command_str &= lchar

                            if last != "":
                                # Must start with command.
                                if command_str.startsWith(last):
                                    completions.add(command_str)
                            else: completions.add(command_str)

                        `type` &= ";nocache"
                        break # Stop once a command-string is found/ran.

                    # Remove last command chain from overall command chain.
                    copy_commandchain = copy_commandchain.replace(pattern)

        # Get filedir of command chain.
        if completions.len == 0:
            let pattern = "^" & quotemeta(commandchain) & " filedir (.+)$"
            let (start, `end`) = findBounds(acdef, re(pattern, {reMultiLine}))
            if start != -1:
                let row = acdef[start .. `end`]
                let kw_index = row.find("filedir")
                let sp_index = row.find(' ', start=kw_index)
                filedir = row[sp_index + 2 .. row.high - 1] # Unquote.

        # Run posthook if it exists.
        if posthook != "":
            const delimiter = "\\r?\\n"
            var r: seq[string] = @[]
            setEnvs(post=true)
            var res = ""
            try: res = execProcess(posthook)
            except: discard
            res = res.strip(trailing=true)
            if res != "": r= split(res, re(delimiter))
            var dsl = false # Delimiter Separated List.
            if r.len != 0:
                let l = last.len
                var filtered: seq[string] = @[]
                var useditems: seq[string] = @[]
                let eqsign_index = last.find('=')
                for c in r:
                    var c = c
                    if c == "__DSL__": dsl = true
                    if c[0] == '!': useditems.add(c[1 .. ^1]); continue
                    if not c.startsWith(last): continue
                    # When completing a delimited separated list, ensure to remove
                    # the flag from every completion item to leave the values only.
                    # [https://unix.stackexchange.com/q/124539]
                    # [https://github.com/scop/bash-completion/issues/240]
                    # [https://github.com/scop/bash-completion/blob/master/completions/usermod]
                    # [https://github.com/scop/bash-completion/commit/021058b38ad7279c33ffbaa36d73041d607385ba]
                    if dsl and c.len >= l: c.delete(0, eqsign_index)
                    filtered.add(c)
                completions = filtered

                if completions.len == 0 and dsl:
                    for c in useditems:
                        var c = c
                        if not c.startsWith(last): continue
                        if dsl and c.len >= l: c.delete(0, eqsign_index)
                        completions.add(c)

    # Send all possible completions to bash.
    proc fn_printer() =
        const sep = "\n"
        var skip_map = false
        let isflag = `type`.startsWith('f')
        let iscommand = not isflag
        let lines = fmt"{`type`}:{last}+{filedir}"

        # Note: When providing flag completions and only "--" is provided,
        # collapse (don't show) flags with the same prefix. This aims to
        # help reduce the `display all n possibilities? (y or n)` message
        # prompt. Instead, only show the prefix in the following format:
        # "--prefix..." along with the shortest completion item.
        if completions.len >= 10 and not iscommand and last == "--":
            # Get completion's common prefixes.
            let res = lcp(
                completions,
                charloop_startindex = 2,
                min_frqz_prefix_len = 2,
                min_prefix_len = 3,
                min_frqz_count = 3,
                char_break_points = ['='],
                prepend = "--",
                append = "..."
            )
            let rm_indices = res.indices

            # Remove strings (collapse) from main array.
            var index = -1
            completions = filter(completions, proc (x: string): bool =
                inc(index)
                # If the index exists in the remove indices table and it's
                # value is set to `true` then do not remove from completions.
                return not (rm_indices.hasKey(index) and rm_indices[index])
            )

            # Add prefix stubs to completions array.
            completions = concat(completions, res.prefixes)

        # When for example, completing 'nodecliac print --command' we remove
        # the first and only completion item's '='. This is better suited for
        # CLI programs that implement/allow for a colon ':' separator. Maybe
        # something that should be opted for via an acmap setting?
        if completions.len == 1 and not iscommand:
            var fcompletion = completions[0]
            if fcompletion =~ re"^--?[-a-zA-Z0-9]+\=$" and last != fcompletion and ((fcompletion.len - last.len) > 1):
                discard chop(fcompletion)
                completions[0] = "\n" & fcompletion
                skip_map = true

        if not skip_map:
            # Loop over completions and append to list.
            completions = map(completions, proc (x: string): string =
                # Add trailing space to all completions except to flag
                # completions that end with a trailing eq sign, commands
                # that have trailing characters (commands that are being
                # completed in the middle), and flag string completions
                # (i.e. --flag="some-word...).
                let final_space = if isflag and not x.endsWith('=') and x.find({'"', '\''}) != 0 and nextchar == "": " " else: ""

                sep & x & final_space
            )

        # Note: bash-completion already sorts completions so this is not needed.
        # However, when testing the results are never returned to bash-completion
        # so the completions need to be sorted for testing purposes.
        if TESTMODE: completions.sort()

        echo lines & completions.join("")

    proc fn_makedb() =
        if commandchain == "": # First level commands only.
            if last == "":
                for line in acdef.splitLines:
                    if not line.startsWith('.'): continue

                    var space_index = line.find(' ')
                    var chain = line.substr(1, space_index - 1)

                    var dot_index = chain.find('.')
                    var command = chain.substr(0, if dot_index != -1: dot_index - 1 else: space_index)

                    if not db_levels.hasKey(1): db_levels[1] = initTable[string, int]()
                    db_levels[1][command] = 1

            else: # First level flags.
                let (start, `end`) = findBounds(acdef, re("^ ([^\n]+)", {reMultiLine}))
                if start != -1:
                    db_dict['_'] = initTable[string, Table[string, seq[string]]]()
                    # + 1 to start bound to ignore captured space (capture groups).
                    # [Bug: https://github.com/nim-lang/Nim/issues/12267]
                    db_dict['_']["_"] = {"flags": @[acdef[start + 1 .. `end`]]}.toTable

        else: # Go through entire .acdef file contents.

            for line in acdef.splitLines:
                var line = line
                if not line.startsWith(commandchain): continue

                let chain = line.substr(0, line.find(' ') - 1)
                line.removePrefix(chain & " ") # Flag list left remaining.

                # If retrieving next possible levels for the command chain,
                # lastchar must be an empty space and the commandchain does
                # not equal the chain of the line, skip the line.
                if lastchar == ' ' and not (chain & ".").startsWith(commandchain & "."): continue

                # Remove starting '.'?
                let commands = (chain).split(re"(?<!\\)\.")

                # Cleanup remainder (flag/command-string).
                if ord(line[0]) == 45:
                    let fchar = chain[1]
                    if not db_dict.hasKey(fchar):
                        db_dict[fchar] = initTable[string, Table[string, seq[string]]]()
                    db_dict[fchar][chain] = {"commands": commands, "flags": @[line]}.toTable

                else: # Store keywords.
                    let keyword = line[0 .. 6]
                    let value = line.substr(8)
                    case (keyword):
                        of "default":
                            if not db_defaults.hasKey(chain): db_defaults[chain] = value
                        of "filedir":
                            if not db_filedirs.hasKey(chain): db_filedirs[chain] = value
                        of "context":
                            if not db_contexts.hasKey(chain): db_contexts[chain] = value
                        else: discard

    fn_tokenize();fn_analyze();fn_makedb();discard fn_lookup();fn_printer()

main()
