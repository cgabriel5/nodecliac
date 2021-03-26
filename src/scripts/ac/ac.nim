#!/usr/bin/env nim

import std/[
        os, osproc, strformat, algorithm, re,
        strutils, sequtils, strscans, tables
    ]

import utils/lcp

proc main() =

    if os.paramCount() == 0: quit()

    let oinput = os.paramStr(1) # Original/unmodified CLI input.
    let cline = os.paramStr(2) # CLI input (could be modified via pre-parse).
    let cpoint = os.paramStr(3).parseInt(); # Index where [tab] key was pressed.
    let maincommand = os.paramStr(4) # Name of command completion is for.
    let acdef = os.paramStr(5) # The command's .acdef file contents.
    let posthook = os.paramStr(6) # Posthook file path.
    let singletons = parseBool(os.paramStr(7)) # Show singleton flags?
    var input = cline.substr(0, cpoint - 1) # CLI input from start to caret index.

    let hdir = os.getEnv("HOME")
    let TESTMODE = os.getEnv("TESTMODE") == "1"

    var isquoted: bool
    var quote_open: bool
    # var autocompletion = true

    var last = ""
    var commandchain = ""
    var completions: seq[string] = @[]
    var lastchar: char # Character before caret.
    let nextchar = cline.substr(cpoint, cpoint) # Character after caret.

    var args: seq[string] = @[]
    var cargs: seq[string] = @[]
    var posargs: seq[string] = @[]
    var ameta: seq[array[2, int]] = @[] # [eq-sign index, isBool]

    # Last parsed flag data.
    var dflag: tuple[flag, value: string, eq: char]

    var comptype = ""
    var filedir = ""

    var usedflags = initTable[string, Table[string, int]]()
    var usedflags_valueless = initTable[string, int]()
    var usedflags_multi = initTable[string, int]()
    var usedflags_counts = initTable[string, int]()

    const C_QUOTES = {'"', '\''}
    const C_SPACES = {' ', '\t'}
    const C_QUOTEMETA = Letters + Digits + {'_'}
    const C_VALID_CMD = Letters + Digits + {'-', '.', '_', ':', '\\'}
    const C_VALID_FLG = Letters + Digits + {'-', '_', }

    type
        Range = array[2, int]
        DBEntry = Table[string, array[2, Range]]

    const LVL1 = 1
    const KEYWORD_LEN = 6

    const C_NL = '\n'
    const C_DOT = '.'
    const C_PIPE = '|'
    const C_SPACE = ' '
    const C_ESCAPE = '\\'
    const C_EXPOINT = '!'
    const C_NUMSIGN = '#'
    const C_EQUALSIGN = '='
    const C_UNDERSCORE = '_'
    const C_SRT_DOT = $C_SPACE
    const C_SPACE_DOT = { C_DOT, C_SPACE }
    const VALID_LINE_STARTS = { C_NUMSIGN, C_NL }

    const O_DEFAULT = 100 # (d)efault
    const O_FILEDIR = 102 # (f)iledir
    const O_CONTEXT = 99  # (c)ontext
    const O_HYPHEN  = 45  # hyphen

    var db_dict = initTable[char, DBEntry]()
    var db_levels = initTable[int, Table[string, int]]()
    var db_defaults = initTable[string, Range]()
    var db_filedirs = initTable[string, Range]()
    var db_contexts = initTable[string, Range]()


    # ----------------------------------------------------- VALIDATION-FUNCTIONS

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

    # --------------------------------------------------------- STRING-FUNCTIONS

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

    # --------------------------------------------------------------------------

    # Regexless alternate to split a string by an unescaped delimiter.
    #     For example, instead of using regex to split by unescaped '|'
    #     chars: 'var flags = flag_list.split(re"(?<!\\)\|")', this
    #     function can be used.
    #
    # @param  {string} s - The source string.
    # @param {char} - The delimiter to split on.
    # @return {array} - The individual strings after split.
    proc splitundel(s: string, DEL: char = '.'): seq[string] =
        runnableExamples:
            var answer: seq[string] = @[]

            answer = @["", "first\\.escaped", "last"]
            doAssert ".first\\.escaped.last".splitundel('.') == answer

            import re
            var s = "--flag|--flag2=$('echo 123 \\| grep 1')"
            answer = @["--flag", "--flag2=$(\'echo 123 \\| grep 1\')"]
            doAssert s.splitundel('|') == answer

        var lastpos = 0
        let EOS = s.high
        const C_ESCAPE = '\\'
        for i, c in s:
            if c == DEL and s[i - 1] != C_ESCAPE:
                result.add(s[lastpos .. i - 1])
                lastpos = i + 1
            elif i == EOS: result.add(s[lastpos .. i])

    # Finds the last unescaped delimiter starting from the right side of
    #     the source string. This is an alternative to using regex like:
    #     'let pattern = re"\.((?:\\\.)|[^\.])+$"'.
    #
    # @param  {string} s - The source string.
    # @param {char} - The delimiter to find.
    # @return {number} - The unescaped delimiter's index.
    proc rlastundel(s: string, DEL: char = '.'): int =
        runnableExamples:
            doAssert rlastundel("nodecliaccommand\\.command") == -1
            doAssert rlastundel(".nodecliaccommand\\.command") == 0
            doAssert rlastundel(".nodecliac.command\\.command") == 10

        const C_ESCAPE = '\\'

        for i in countdown(s.high, s.low):
            if s[i] == DEL:
                if i == 0 or (i - 1 > -1 and s[i - 1] != C_ESCAPE):
                    return i
        result = -1

    # --------------------------------------------------------------------------

    # Predefine procs to maintain proc order with ac.pl.
    proc parseCmdStr(input: string): seq[string]
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
    proc execCommand(cmdstr: string): seq[string] =
        var arguments = parseCmdStr(cmdstr)
        unquote(arguments[0]) # Uncomment command.

        # Build '$' command parameters.
        for i in countup(1, arguments.high):
            if arguments[i][0] == '$':
                discard shift(arguments[i]) # Remove '$'.
                let q = arguments[i][0]
                unquote(arguments[i])
                # Wrap command in ticks to target common (sh)ell.
                arguments[i] = q & "`" & arguments[i] & "`" & q

        setEnvs()
        var res = (
            try: execProcess(arguments.join(" "))
            except: ""
        ).string
        res.stripLineEnd()
        result = splitLines(res)

    # Parse command string `$("")` and returns its arguments.
    #
    # Syntax:
    # $("COMMAND-STRING" [, [<ARG1>, <ARGN> [, "<DELIMITER>"]]])
    #
    # @param  {string} input - The string command-flag to parse.
    # @return {string} - The cleaned command-flag string.
    proc parseCmdStr(input: string): seq[string] =
        type
            CMDArgSlice = tuple
                start, stop: int
                espipes: seq[int]

        const C_PIPE = '|'
        const C_NULLB = '\0'
        const C_ESCAPE = '\\'
        const C_DOLLARSIGN = '$'
        const C_QUOTES = {'"', '\''}

        if input.len == 0: return

        var c, p, q: char
        var start: int = -1
        var espipes: seq[int] = @[]
        var ranges: seq[CMDArgSlice] = @[]

        var i = 0; let l = input.len
        while i < l:
            swap(p, c)
            c = input[i]

            if q == C_NULLB:
                if c in C_QUOTES and p != C_ESCAPE:
                    if start == -1: start = i
                    q = c
                elif ranges.len > 0 and c == C_DOLLARSIGN:
                    if start == -1: start = i
            else:
                if c == C_PIPE and p == C_ESCAPE: espipes.add(i - start)

                if c == q and p != C_ESCAPE:
                    if start != -1:
                        ranges.add((start, i, espipes))
                        espipes.setLen(0)
                        start = -1
                        q = C_NULLB

            inc(i)

        # Finish last range post loop.
        if start > -1 and start != l:
            ranges.add((start, input.high, espipes))

        # Use slices to get arguments.
        result = newSeqOfCap[string](ranges.len)
        for i, rng in ranges:
            let (start, stop, espipes) = rng
            var arg = input[start .. stop]
            if espipes.len > 0: # Unescape pipe chars.
                for j in countdown(espipes.high, 0):
                    let rindex = espipes[j] - 1
                    arg.delete(rindex, rindex)
            result.add(arg)

    # Set environment variables to access in custom scripts.
    #
    # @param  {string} arguments - N amount of env names to set.
    # @return - Nothing is returned.
    proc setEnvs(arguments: varargs[string], post=false) =
        let l = args.len
        const prefix = "NODECLIAC_"
        let ctype = (if comptype[0] == 'c': "command" else: "flag")
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
            # CLI input from caret index to input string end.
            fmt"{prefix}INPUT_REMAINDER": cline.substr(cpoint, -1),
            fmt"{prefix}LAST_CHAR": $lastchar, # Character before caret.
            # Character after caret. If char is not '' (empty) then the last word
            # item is a partial word.
            fmt"{prefix}NEXT_CHAR": nextchar,
            # Original input's length.
            fmt"{prefix}COMP_LINE_LENGTH": intToStr(cline.len),
            # CLI input length from beginning of string to caret position.
            fmt"{prefix}INPUT_LINE_LENGTH": intToStr(input.len),
            # Amount arguments parsed before caret position/index.
            fmt"{prefix}ARG_COUNT": intToStr(l),
            # Store collected positional arguments after validating the
            # command-chain to access in plugin auto-completion scripts.
            fmt"{prefix}USED_DEFAULT_POSITIONAL_ARGS": posargs.join("\n"),
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

    # ----------------------------------------------------------- MAIN-FUNCTIONS

    var ranges = newSeqOfCap[Range](countLines(acdef))

    # Loop over acdef and generate line ranges.
    #
    # @return - Nothing is returned.
    proc fn_ranges() =
        var pos = 0
        var lastpos = 0
        while true:
            pos = find(acdef, sub = C_NL, start = pos + 1)
            if pos == -1:
                # Handle case where only one line exists.
                if lastpos != -1: ranges.add([lastpos, acdef.high])
                break
            if lastpos != pos and acdef[lastpos] != C_NUMSIGN:
                ranges.add([lastpos, pos - 1])
            lastpos = pos + 1

    # Parses CLI input.
    #
    # @return - Nothing is returned.
    proc fn_tokenize() =
        if input == "": return

        const C_NULLB = '\0'
        const C_ESCAPE = '\\'
        const C_COLON = ':'
        const C_HYPHEN = '-'
        const C_QUOTES = {'"', '\''}
        const C_SPACES = {' ', '\t'}
        const FLAGVAL_DELS = { C_COLON, C_EQUALSIGN }

        type
            ArgSlice = array[4, int] # [start, stop, eqsign_index, is_singleton]

        # Spreads single hyphen flags: ex: '-n5 -abc "val"' => '-n 5 -a -b -c "val"'
        #
        # @param  {ArgSlice} item - The slice to unpack.
        # @return {seq[ArgSlice]} - The unpacked slices.
        # @resource [https://serverfault.com/a/387936]
        # @resource [https://nullprogram.com/blog/2020/08/01/]
        proc unpcka(item: ArgSlice): seq[ArgSlice] =
            let start = item[0]
            let stop = item[1]

            # Short circuit if not a single hyphen flag or contain an '='.
            if (stop - start) < 2 or input[start] != C_HYPHEN or
                input[start + 1] == C_HYPHEN or item[2] != -1:
                result.add(item)
                return

            # Plus 1 to start to ignore single '-'.
            for i in countup(start + 1, stop):
                if input[stop] in Digits:
                    if input[i] notin Digits: result.add([i, i, -1, 1])
                    else: (result.add([i, stop, -1, 0]); break)
                else: result.add([i, i, -1, 1])

        proc strfromrange(s: string, start, stop: int, prefix: string = ""): string =
            runnableExamples:
                var s = "nodecliac debug --disable"
                doAssert "nodecliac" == strfromrange(s, 0, 8)

            let pl = prefix.len
            # [https://forum.nim-lang.org/t/707#3931]
            # [https://forum.nim-lang.org/t/735#4170]
            result = newStringOfCap((stop - start + 1) + pl)
            if pl > 0: (for c in prefix: result.add(c))
            for i in countup(start, stop): result.add(s[i])
            # The resulting indices may also be populated with builtin slice
            # notation. However, using a loop shows to be slightly faster.
            # [https://github.com/nim-lang/Nim/pull/2171/files]
            # result[result.low .. result.high] = s[start ..< stop]
            shallow(result)

        # Parses CLI input into its individual arguments and normalizes any
        #     flag/value ':' delimiters to '='.
        #
        # @return - Nothing is returned.
        proc fn_argslices(): seq[ArgSlice] =
            if input.len == 0: return

            var c, p, q: char
            var start, eqsign: int = -1

            var i = 0; let l = input.len
            while i < l:
                swap(p, c)
                c = input[i]

                if q != C_NULLB:
                    if c == q and p != C_ESCAPE:
                        if start != -1:
                            result.add([start, i, eqsign, 0])
                            eqsign = -1
                            start = -1
                            q = C_NULLB

                else:
                    if c in C_QUOTES and p != C_ESCAPE:
                        if start == -1: start = i
                        q = c

                    elif c in C_SPACES and p != C_ESCAPE:
                        if start != -1:
                            let targ = [start, i - 1, eqsign, 0]
                            for uarg in unpcka(targ): result.add(uarg)
                            eqsign = -1
                            start = -1

                    else:
                        if start == -1: start = i
                        if c in FLAGVAL_DELS and eqsign == -1 and
                                input[start] == C_HYPHEN:
                            input[i] = C_EQUALSIGN # Normalize ':' to '='.
                            eqsign = i - start
                inc(i)

            # Finish last point post loop.
            if start > -1 and start != l:
                let targ = [start, input.high, eqsign, 0]
                for uarg in unpcka(targ): result.add(uarg)

            # If the qchar is set, there was an unclosed string like:
            # '$ op list itema --categories="Outdoor '
            if q != C_NULLB: quote_open = true

            # Get last char of input.
            lastchar = if not (c != ' ' and p != '\\'): c else: '\0'

        let ranges = fn_argslices()
        let l = ranges.len

        # # Using the found argument ranges, create strings of them.
        # var args = newSeqOfCap[tuple[arg: string, eqsign: int]](l)
        # for rng in ranges:
        #     let prefix = $(if rng[3] == 1: C_HYPHEN else: C_NULLB)
        #     args.add((strfromrange(input, rng[0], rng[1] + 1, prefix), rng[2]))

        # Using the found argument ranges, create strings of them.
        # var args = newSeqOfCap[tuple[arg: string, eqsign: int]](l)
        for rng in ranges:
            let prefix = if rng[3] == 1: "-" else: ""
            args.add(strfromrange(input, rng[0], rng[1], prefix))
            ameta.add([rng[2], 0])

    # Wrapper for builtin cmp function. This function returns a boolean.
    #
    # @param  {string} a - The first string.
    # @param  {string} b - The second string.
    # @return {boolean} - Whether strings are the same or not.
    proc eq(a, b: string): bool = cmp(a, b) == 0

    # Looks for the first row in acdef that matches the provided
    #     command chain. This is a non regex alternative to re.findBounds.
    #
    # @param  {string} s - The source string.
    # @param  {string} sub - The needle to find.
    # @return {array} - The range of the command chain row.
    proc lookupcmd(s, sub: string): Range =
        const C_SPACE = ' '

        for i, rng in ranges:
            block innerLoop:
                # Skip range if shorter than string.
                if rng[1] - rng[0] < sub.len: continue
                for j, c in sub:
                    if c != s[rng[0] + j]:
                        break innerLoop

                # If everything has matched up to this point,
                # get the index of the first space in the line.
                for k in countup(sub.high, rng[1]):
                    if s[k] == C_SPACE:
                        return [rng[0], rng[0] + k]
        return [-1, 0]

    # Looks for the first row in acdef that matches the provided
    #     command chain and returns the indices of its flags. This
    #     is a non regex alternative to re.findBounds.
    #
    # @param  {string} s - The source string.
    # @param  {string} sub - The needle to find.
    # @param  {number} start - Index where search should begin.
    # @return {array} - The range of the command chain flags.
    proc lookupflg(s, sub: string, start: int = 0): Range =
        for i, rng in ranges:
            block innerLoop:
                if rng[0] < start: continue
                # Skip range if shorter than string.
                if rng[1] - rng[0] < sub.len: continue
                for j, c in sub:
                    if c != s[rng[0] + j]:
                        break innerLoop

                # If everything has matched up to this point,
                # return the [index after commandchain, to the end of line].
                return [rng[0] + sub.len, rng[1]]
        return [-1, 0]

    # Looks for the first keyword row in acdef that matches the provided
    #     command chain. This is a non regex alternative to re.findBounds.
    #
    # @param  {string} s - The source string.
    # @param  {string} sub - The needle to find.
    # @param  {number} kind - Keyword to search for (context|filedir).
    # @return {array} - The range of the command chain row.
    proc lookupkw(s, sub: string, kind: int): Range =
        let postsub = if kind == 1: " context " else: " filedir "

        for i, rng in ranges:
            block innerLoop:
                # Skip range if shorter than string.
                if rng[1] - rng[0] < sub.len: continue
                for j, c in sub:
                    if c != s[rng[0] + j]:
                        break innerLoop

                for k, c in postsub:
                    if c != s[rng[0] + k + sub.len]:
                        break innerLoop

                # If everything has matched up to this point,
                # get the index of the first space in the line.
                return [rng[0] + sub.len + postsub.len + 1,
                        rng[1] - 1] # +2 and -1 to unquote.
        return [-1, 0]

    # Determine command chain, used flags, and set needed variables.
    #
    # @return - Nothing is returned.
    proc fn_analyze() =
        let l = args.len
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

        # RegEx lookup templates.
        const template_cmd = "^$1[^ ]* "
        const template_flg = "^$1(.+)$"

        var i = 1; while i < l:
            var item = args[i]
            let nitem = if i + 1 < l: args[i + 1] else: ""

            # # Skip quoted or escaped items.
            # if item[0] in C_QUOTES or '\\' in item:
            #     posargs.add(item)
            #     cargs.add(item)
            #     inc(i)
            #     continue

            if item[0] != '-':
                let command = fn_normalize_command(item)
                var tmpchain = commandchain & "." & command

                let rng = acdef.lookupcmd(tmpchain)
                if rng[0] != -1:
                    chainstring = acdef[rng[0] .. rng[1]]
                    bound = rng[0]
                    commandchain &= fn_validate_command("." & command)
                else: posargs.add(item)

                cargs.add(item)

            else:

                # If a flag has an eq-sign and therefore possible
                # a value, simply split the flag/value and store it.
                if ameta[i][0] > -1:
                    cargs.add(item)

                    let flag = item[0 .. ameta[i][0] - 1]
                    let value = item[ameta[i][0] .. item.high]
                    trackusedflag(flag, value)
                    trackflagcount(flag)

                    inc(i); continue

                let flag = fn_validate_flag(item)
                let rng = acdef.lookupflg(chainstring, start=bound)
                # Determine whether flag is a boolean flag.
                if acdef.rfind(flag & "?", rng[0], last = rng[1]) > 0:
                    cargs.add(flag)
                    ameta[i][1] = 1
                    trackvaluelessflag(flag)

                else:
                    if nitem != "" and nitem[0] != '-':
                        let vitem = flag & "=" & nitem
                        cargs.add(vitem)
                        ameta[i][0] = flag.len

                        trackusedflag(flag, nitem)

                        inc(i)
                    else:

                        # Check whether flag needs to be normalized.
                        # For example, the following input:
                        # 'nodecliac print --command [TAB]'
                        # will gets converted into:
                        # 'nodecliac print --command=[TAB]'
                        if (i == args.high) and lastchar == ' ':
                            let aflag = flag & "="
                            # last = aflag
                            lastchar = '\0'
                            cargs.add(aflag)
                            args[^1] = aflag
                        else:
                            cargs.add(flag)

                        trackvaluelessflag(flag)

                trackflagcount(flag)

            inc(i)

        # Perform final reset(s).
        last = if lastchar == ' ': "" else: cargs[^1]
        # Reset if completion is being attempted for a quoted/escaped string.
        if lastchar == ' ' and cargs.len > 0:
            let litem = cargs[^1]
            quote_open = quote_open and litem[0] == '-'
            # Skip single letter sub-commands like in input: '$ nim c '
            if litem.len > 2 and (litem[0] in C_QUOTES or
                quote_open or litem[^2] == '\\'):
                last = litem
        if last.find(C_QUOTES) == 0: isquoted = true

    # Lookup acdef definitions.
    #
    # @return - Nothing is returned.
    proc fn_lookup(): string =
        # if isquoted or not autocompletion: return ""

        if last.startsWith('-'):
            comptype = "flag"

            var letter = if commandchain != "": commandchain[1] else: '_'
            commandchain = if commandchain != "": commandchain else: "_"
            if db_dict.hasKey(letter) and db_dict[letter].hasKey(commandchain):
                var excluded = initTable[string, int]()
                var parsedflags = initTable[string, int]()
                let frange = db_dict[letter][commandchain][1]
                var flag_list = acdef[frange[0] .. frange[1]]

                # Explanation how scanf + custom definable matcher works:
                # The provided source string (s) is provided to loop over characters.
                # Characters are looped over and processed against the necessary
                # char set (chars). With that being said, looping starts at the index
                # where the ${matcherName}/$[matcherName] was invoked. This is index
                # (start) corresponds to that start point. It is the matcher functions
                # job to determine whether characters pass or fail the match. When
                # characters match the captured string (str) can be built. The final
                # thing to note is that the matcher must return an integer. This integer
                # must be the resume index where the main loop/parser must continue off
                # at. This index is different than that of the (start) index parameter.
                # This value must be the amount of characters the matcher function ate.
                # As shown below, if the (start) index is copied, it can then be
                # calculated as `i - start`.
                #
                # User definable matcher for scanf which checks that the placeholder
                #     contains valid characters.
                #
                # @param  {string} s - The source string.
                # @param {string} str - The string being built/captured string.
                # @param {number} start - Index where parsing starts.
                # @param {set[char]} chars - Valid parsing characters.
                # @return {number} - Amount of characters matched/eaten.
                proc placeholder(s: string; str: var string; start: int;
                    chars: set[char] = HexDigits): int =

                    runnableExamples:
                        var match: string
                        if scanf("--p#07d43e", "--p#${placeholder}$.", match):
                            echo "[", match, "]"

                    var i = start
                    let l = s.len
                    const maxlen = 6 # Cache file names are exactly 6 chars.
                    while i < s.len and str.len <= maxlen:
                        if s[i] notin chars: break
                        str.add($s[i]); inc(i)
                    # If cache file name is not 6 characters don't capture anything
                    # as the name is invalid. Therefore reset the index to 0 which
                    # signals the parent parser that nothing was matched/eaten.
                    if str.len != maxlen: i = 0
                    return (i - start) # Resume index (count of eaten chars).

                # If a placeholder get its contents.
                var cplname: string
                if flag_list.startsWith("--p#") and
                    scanf(flag_list, "--p#${placeholder}$.", cplname):
                    flag_list = readFile(hdir & "/.nodecliac/registry/" & maincommand & "/placeholders/" & cplname)

                if flag_list == "--":  return ""

                # Split by unescaped pipe '|' characters:
                var flags = flag_list.splitundel(C_PIPE)

                # Context string logic: start ----------------------------------

                let cchain = if commandchain == "_": "" else: quotemeta(commandchain)
                let rng = acdef.lookupkw(cchain, 1)
                if rng[0] != -1:
                    let context = acdef[rng[0] .. rng[1]]

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

                # Context string logic: end ------------------------------------

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
                dflag = (last_fkey, last_value, last_eqsign)

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
                            comptype = "flag;nocache"
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

                    # [Start] Remove duplicate flag logic ----------------------

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

                    # [End] Remove duplicate flag logic ------------------------

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
                    comptype = "flag;quoted"
                    if quote == '\"': comptype &= ";noescape"

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

            comptype = "command"

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
                var commands = commandchain.splitundel(C_DOT)
                var level = commands.len - 1
                # Increment level if completing a new command level.
                if lastchar == ' ': inc(level)

                # If level does not match argument length, return. As the
                # parsed arguments do not match that of a valid commandchain.
                let la = (cargs.len + 1) - usedflags_counts.len
                if not ((la == level + 1 and lastchar != '\0') or
                    (la > level and lastchar != '\0') or (la - level > 1)):

                    # Get commandchains for specific letter outside of loop.
                    var h = db_dict[letter]

                    for row in rows:
                        var row = row
                        # Command must exist.
                        # if not h[row].hasKey("commands"): continue # Needed?

                        var cmds = acdef[ h[row][0][0] .. h[row][0][1] ].split(".")
                        row = if level < cmds.len: cmds[level] else: ""

                        # Add last command if not yet already added.
                        if row == "" or usedcommands.hasKey(row): continue
                        # If char before caret isn't a space, completing a command.
                        if lastchar_notspace:
                            if row.startsWith(last):
                                let c = commandchain.endsWith("." & row)
                                if (not c or (c and lastchar == '\0')) or
                                posargs.len == 0 and lastchar == '\0':
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

                # Loop over command chains to build individual chain levels.
                while copy_commandchain != "":
                    # Get command-string, parse and run it.
                    let crange = db_defaults.getOrDefault(copy_commandchain, [-1, -1])
                    var command_str = (
                        if crange != [-1, -1]: acdef[crange[0] .. crange[1]]
                        else: ""
                    )

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
                                if findBounds(lines.join("\n"), re(
                                    "^\\!?" & quotemeta(last) & "$",
                                    {reMultiLine})).first != -1:
                                    completions.add(last)

                        # Static value.
                        else:
                            command_str &= lchar

                            if last != "":
                                # Must start with command.
                                if command_str.startsWith(last):
                                    completions.add(command_str)
                            else: completions.add(command_str)

                        comptype &= ";nocache"
                        break # Stop once a command-string is found/ran.

                    # Remove last command chain from overall command chain.
                    copy_commandchain.setLen(rlastundel(copy_commandchain))

        # Get filedir of command chain.
        if completions.len == 0:
            let rng = acdef.lookupkw(commandchain, 2)
            if rng[0] != -1: filedir = acdef[rng[0] .. rng[1]]

        # Run posthook if it exists.
        if posthook != "":
            setEnvs(post=true)
            var res = (
                try: execProcess(posthook)
                except: ""
            ).string
            res.stripLineEnd()
            var lines = splitLines(res)
            if lines.len == 1 and lines[0] == "": lines.setLen(0)

            if lines.len != 0:
                let l = last.len
                const DSL_IDENT = "__DSL__"
                var useditems: seq[string] = @[]
                let eqsign_index = last.find(C_EQUALSIGN)
                var isDSL = false # Delimiter Separated List.
                completions.setLen(0)
                for i in countup(0, lines.high):
                    if lines[i] == DSL_IDENT: isDSL = true
                    if lines[i][0] == C_EXPOINT:
                        discard shift(lines[i])
                        useditems.add(lines[i])
                        continue
                    if not lines[i].startsWith(last): continue
                    # When completing a delimited separated list, ensure to remove
                    # the flag from every completion item to leave the values only.
                    # [https://unix.stackexchange.com/q/124539]
                    # [https://github.com/scop/bash-completion/issues/240]
                    # [https://github.com/scop/bash-completion/blob/master/completions/usermod]
                    # [https://github.com/scop/bash-completion/commit/021058b38ad7279c33ffbaa36d73041d607385ba]
                    if isDSL and lines[i].len >= l: lines[i].delete(0, eqsign_index)
                    completions.add(lines[i])

                if completions.len == 0 and isDSL:
                    for i in countup(0, useditems.high):
                        if not useditems[i].startsWith(last): continue
                        if isDSL and useditems[i].len >= l:
                            useditems[i].delete(0, eqsign_index)
                        completions.add(useditems[i])

    # Send all possible completions to bash.
    proc fn_printer() =
        const sep = "\n"
        var skip_map = false
        let isflag = comptype.startsWith('f')
        let iscommand = not isflag
        let lines = fmt"{comptype}:{last}+{filedir}"

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

    # Checks whether string starts with given substring and optional suffix.
    proc cmpstart(s, sub, suffix: string = ""): bool =
        runnableExamples:
          var s, sub: string = ""

          s = ".disable.second"
          sub = ".disable"
          doAssert cmpstart(s, sub, suffix = ".") == true

          s = ".disable.second"
          sub = ".disable.last"
          doAssert cmpstart(s, sub, suffix = ".") == false

          s = ".disable.second"
          sub = ".disable"
          doAssert cmpstart(s, sub, suffix = "+") == false

        let ls = suffix.len
        if (sub.len + ls) > (s.len + ls): return

        var i = 0
        for c in sub:
            if sub[i] != s[i]: return
            inc(i)

        # Compare suffix if provided.
        if ls > 0:
            for c in suffix:
              if c != s[i]: return
              inc(i)

        return true

    # Checks whether provided substring is found at the start/stop indices
    #     at the source string.
    proc cmpindices(s, sub: string, start, stop: int): bool =
        if sub.len > (stop - start): return

        var index = start
        for c in sub:
            if c != s[index]: return
            inc(index)
        return true

    proc strfromrange(s: string, start, stop: int, prefix: string = ""): string =
        runnableExamples:
            var s = "nodecliac debug --disable"
            doAssert "nodecliac" == strfromrange(s, 0, 8)

        let pl = prefix.len
        # [https://forum.nim-lang.org/t/707#3931]
        # [https://forum.nim-lang.org/t/735#4170]
        result = newStringOfCap((stop - start + 1) + pl)
        if pl > 0: (for c in prefix: result.add(c))
        for i in countup(start, stop): result.add(s[i])
        # The resulting indices may also be populated with builtin slice
        # notation. However, using a loop shows to be slightly faster.
        # [https://github.com/nim-lang/Nim/pull/2171/files]
        # result[result.low .. result.high] = s[start ..< stop]
        shallow(result)

    proc fn_makedb() =
        if commandchain == "": # First level commands only.
            if last == "":
                db_levels[LVL1] = initTable[string, int]()

                for rng in ranges:
                    let start = rng[0]
                    let stop = rng[1]

                    if acdef[start] == C_SPACE: continue

                    # Add 1 to start to skip the initial dot in command chain.
                    let command = strfromrange(acdef, start + 1, find(acdef,
                        C_SPACE_DOT, start + 1, stop) - 1)
                    if command notin db_levels[LVL1]: db_levels[LVL1][command] = LVL1

            else: # First level flags.

                db_dict[C_UNDERSCORE] = DBEntry()

                for rng in ranges:
                    let start = rng[0]
                    let stop = rng[1]

                    if acdef[start] == C_SPACE:
                        db_dict[C_UNDERSCORE][$C_UNDERSCORE] =
                            [[start, start], [start + 1, stop]]
                        break

        else: # Go through entire .acdef file contents.

            for rng in ranges:
                let start = rng[0]
                let stop = rng[1]

                # Line must start with commandchain
                if not cmpindices(acdef, commandchain, start, stop): continue

                # Locate the first space character in the line.
                let sindex = find(acdef, C_SPACE, start, stop)
                let chain = strfromrange(acdef, start, sindex - 1)

                # # If retrieving next possible levels for the command chain,
                # # lastchar must be an empty space and the commandchain does
                # # not equal the chain of the line, skip the line.
                # if lastchar == C_SPACE and not chain.cmpstart(commandchain, C_SRT_DOT):
                #     continue

                # let commands = splitundel(chain)

                # Cleanup remainder (flag/command-string).
                let rindex = sindex + 1
                let fchar = chain[1]
                if ord(acdef[rindex]) == O_HYPHEN:
                    if fchar notin db_dict: db_dict[fchar] = DBEntry()
                    db_dict[fchar][chain] = [[start, sindex - 1], [rindex, stop]]

                else: # Store keywords.
                    # The index from the start of the keyword value string to end of line.
                    let value = [rindex + (KEYWORD_LEN + 2), stop]
                    case ord(acdef[rindex]): # Keyword first char keyword.
                    of O_DEFAULT: (if chain notin db_defaults: db_defaults[chain] = value)
                    of O_FILEDIR: (if chain notin db_filedirs: db_filedirs[chain] = value)
                    of O_CONTEXT: (if chain notin db_contexts: db_contexts[chain] = value)
                    else: discard

    fn_ranges();fn_tokenize();fn_analyze();fn_makedb();discard fn_lookup();fn_printer()

main()
