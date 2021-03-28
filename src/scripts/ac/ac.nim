import std/[os, osproc, algorithm, strutils, sequtils, strscans, tables]

import utils/lcp

proc main() =

    if paramCount() == 0: quit()

    let
        oinput = paramStr(1) # Original/unmodified CLI input.
        cline = paramStr(2) # CLI input (could be modified via pre-parse).
        cpoint = paramStr(3).parseInt() # Index where [tab] key was pressed.
        maincommand = paramStr(4) # Name of command completion is for.
        acdef = paramStr(5) # The command's .acdef file contents.
        posthook = paramStr(6) # Posthook file path.
        singletons = parseBool(paramStr(7)) # Show singleton flags?
    var input = cline[0 ..< cpoint] # CLI input from start to caret index.

    # --------------------------------------------------------------------------

    type
        Range = array[2, int]
        DBEntry = Table[string, array[2, Range]]

    const
        LVL1 = 1
        KEYWORD_LEN = 6

        C_LC = 'c'
        C_LF = 'f'

        C_LPAREN = '('
        C_RPAREN = ')'
        C_LCURLY = '{'
        C_RCURLY = '}'

        C_NL = '\n'
        C_DOT = '.'
        C_TAB = '\t'
        C_PIPE = '|'
        C_COMMA = '.'
        C_COLON = ':'
        C_QMARK = '?'
        C_SPACE = ' '
        C_NULLB = '\0'
        C_HYPHEN = '-'
        C_FSLASH = '/'
        C_DQUOTE = '\"'
        C_SQUOTE = '\''
        C_ESCAPE = '\\'
        C_EXPOINT = '!'
        C_NUMSIGN = '#'
        C_ASTERISK = '*'
        C_SEMICOLON = ';'
        C_EQUALSIGN = '='
        C_DOLLARSIGN = '$'
        C_UNDERSCORE = '_'

        C_STR_DOT = $C_SPACE

        C_SPACES = {C_SPACE, C_TAB}
        C_SPACE_DOT = {C_DOT, C_SPACE}
        C_QUOTES = {C_DQUOTE, C_SQUOTE}

        C_ALPHANUMR = Letters + Digits
        C_FLAG_DELS = {C_COLON, C_EQUALSIGN}
        C_QUOTEMETA = C_ALPHANUMR + {C_UNDERSCORE}
        C_VALID_FLG = C_ALPHANUMR + {C_HYPHEN, C_UNDERSCORE}
        C_VALID_CMD = C_ALPHANUMR + {C_HYPHEN, C_DOT, C_UNDERSCORE,
                                        C_COLON, C_ESCAPE}

        O_DEFAULT = 100 # (d)efault
        O_FILEDIR = 102 # (f)iledir
        O_CONTEXT = 99  # (c)ontext
        O_HYPHEN  = 45  # (-)hyphen

    let
        hdir = getEnv("HOME")
        TESTMODE = getEnv("TESTMODE") == "1"
        nextchar: char = cline[cpoint] # Character after caret.

    var
        last: string
        commandchain: string
        completions: seq[string] = @[]
        lastchar: char # Character before caret.

        isquoted: bool
        quote_open: bool
        # autocompletion = true
        comptype: string
        filedir: string

        args: seq[string]
        cargs: seq[string] = @[]
        posargs: seq[string] = @[]
        ameta: seq[array[2, int]] = @[] # [eq-sign index, isBool]

        usedflags = initTable[string, Table[string, int]]()
        usedflags_valueless = initTable[string, int]()
        usedflags_multi = initTable[string, int]()
        usedflags_counts = initTable[string, int]()

        db_dict = initTable[char, DBEntry]()
        db_levels = initTable[int, Table[string, int]]()
        db_defaults = initTable[string, Range]()
        db_filedirs = initTable[string, Range]()
        db_contexts = initTable[string, Range]()

        # Last flag data.
        dflag: tuple[flag, value, eq: string]

    # --------------------------------------------------------- HELPER-FUNCTIONS

    # Wrapper for builtin cmp function which returns a boolean instead
    #     of a number for convenience.
    #
    # @param  {string} a - The first string.
    # @param  {string} b - The second string.
    # @return {boolean} - Whether strings are the same or not.
    func eq(a, b: string): bool {.inline.} = cmp(a, b) == 0

    # Negate wrapper for builtin cmp function which returns a boolean
    #    instead of a number for convenience.
    #
    # @param  {string} a - The first string.
    # @param  {string} b - The second string.
    # @return {boolean} - Whether strings are the same or not.
    func neq(a, b: string): bool {.inline.} = cmp(a, b) != 0

    # Helper function which checks whether a string is not empty.
    #
    # @param  {string} a - The string.
    # @return {boolean} - Whether string is empty or not.
    func strset(s: string): bool {.inline.} = s.len > 0

    # Helper function which checks whether a char is not empty.
    #
    # @param  {char} a - The character.
    # @return {boolean} - Whether char is empty or not.
    func chrset(c: char): bool {.inline.} = c != C_NULLB

    # Helper function which checks whether sequence/array if empty.
    #
    # @param  {openarray} a - The list.
    # @return {boolean} - Whether list is empty or not.
    func emp(a: openarray[any]): bool {.inline.} = a.len == 0

    # ----------------------------------------------------- VALIDATION-FUNCTIONS

    # Peek string for '/','~'. If contained assume it's a file/dir.
    #
    # @param  {string} item - The string to check.
    # @return {bool}
    proc fn_is_file_or_dir(item: string): bool =
        C_FSLASH in item or eq(item, "~")

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
    proc shift(s: var string, stop: int = 0): char =
        result = s[0]
        s.delete(0, stop)

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
    proc splitchars(s: string): seq[char] = mapIt(s, it)

    # Substitute for Perl's quotemeta function.
    #
    # @param  {string} s - The string to escape.
    # @return {string} - The escaped string.
    # @resource [https://perldoc.perl.org/functions/quotemeta.html]
    proc quotemeta(s: string): string =
        for c in s: result.add(if c notin C_QUOTEMETA: C_ESCAPE & c else: $c)

    # --------------------------------------------------------------------------

    # Regexless alternate to split a string by an unescaped delimiter.
    #     For example, instead of using regex to split by unescaped '|'
    #     chars: 'var flags = flag_list.split(re"(?<!\\)\|")', this
    #     function can be used.
    #
    # @param  {string} s - The source string.
    # @param {char} - The delimiter to split on.
    # @return {array} - The individual strings after split.
    proc splitundel(s: string, DEL: char = C_DOT): seq[string] =
        runnableExamples:
            var answer: seq[string] = @[]

            answer = @["", "first\\.escaped", "last"]
            doAssert ".first\\.escaped.last".splitundel(C_DOT) == answer

            import re
            var s = "--flag|--flag2=$('echo 123 \\| grep 1')"
            answer = @["--flag", "--flag2=$(\'echo 123 \\| grep 1\')"]
            doAssert s.splitundel(C_PIPE) == answer

        var lastpos = 0
        let EOS = s.high
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
    proc rlastundel(s: string, DEL: char = C_DOT): int =
        runnableExamples:
            doAssert rlastundel("nodecliaccommand\\.command") == -1
            doAssert rlastundel(".nodecliaccommand\\.command") == 0
            doAssert rlastundel(".nodecliac.command\\.command") == 10

        for i in countdown(s.high, s.low):
            if s[i] == DEL:
                if i == 0 or (i - 1 > -1 and s[i - 1] != C_ESCAPE):
                    return i
        result = -1

    # --------------------------------------------------------------------------

    # Predefine procs to maintain proc order with ac.pl.
    proc parseCmdStr(input: string): seq[string]
    proc setEnvs(arguments: varargs[string], post = false)

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
            if arguments[i][0] == C_DOLLARSIGN:
                discard shift(arguments[i]) # Remove '$'.
                let q = arguments[i][0]
                unquote(arguments[i])
                # Wrap command in ticks to target common (sh)ell.
                arguments[i] = q & "`" & arguments[i] & "`" & q

        setEnvs()
        var res = (try: execProcess(arguments.join(" ")) except: "").string
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

        if not strset(input): return

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
    proc setEnvs(arguments: varargs[string], post = false) =
        let l = args.len
        const IDENT_CMD = "command"
        const IDENT_FLG = "flag"
        let ctype = if comptype[0] == C_LC: IDENT_CMD else: IDENT_FLG

        # Get any used flags to pass along.
        var usedflags: seq[string] = @[]
        for k in usedflags_counts.keys: usedflags.add(k)

        # nodecliac exposed Bash env vars.

        putEnv("NODECLIAC_COMP_LINE", cline) # Original (unmodified) CLI input.
        # Caret index when [tab] key was pressed.
        putEnv("NODECLIAC_COMP_POINT", intToStr(cpoint))

        # nodecliac env vars.

        # The command auto completion is being performed for.
        putEnv("NODECLIAC_MAIN_COMMAND", maincommand)
        putEnv("NODECLIAC_COMMAND_CHAIN", commandchain) # The parsed command chain.
        putEnv("NODECLIAC_USED_FLAGS", usedflags.join("\n")) # The parsed used flags.
        # The last parsed word item (note: could be a partial word item.
        # This happens when the [tab] key gets pressed within a word item.
        # For example, take the input 'maincommand command'. If
        # the [tab] key was pressed like so: 'maincommand comm[tab]and' then
        # the last word item is 'comm' and it is a partial as its remaining
        # text is 'and'. This will result in using 'comm' to determine
        # possible auto completion word possibilities.).
        putEnv("NODECLIAC_LAST", last)
        # The word item preceding last word item.
        putEnv("NODECLIAC_PREV", args[^(if not post: 2 else: 1)])
        putEnv("NODECLIAC_INPUT", input) # CLI input from start to caret index.
        putEnv("NODECLIAC_INPUT_ORIGINAL", oinput) # Original unmodified CLI input.
        # CLI input from caret index to input string end.
        putEnv("NODECLIAC_INPUT_REMAINDER", cline[cpoint .. cline.high])
        putEnv("NODECLIAC_LAST_CHAR", $lastchar) # Character before caret.
        # Character after caret. If char is not '' (empty) then the last word
        # item is a partial word.
        putEnv("NODECLIAC_NEXT_CHAR", $nextchar)
        # Original input's length.
        putEnv("NODECLIAC_COMP_LINE_LENGTH", intToStr(cline.len))
        # CLI input length from beginning of string to caret position.
        putEnv("NODECLIAC_INPUT_LINE_LENGTH", intToStr(input.len))
        # Amount arguments parsed before caret position/index.
        putEnv("NODECLIAC_ARG_COUNT", intToStr(l))
        # Store collected positional arguments after validating the
        # command-chain to access in plugin auto-completion scripts.
        putEnv("NODECLIAC_USED_DEFAULT_POSITIONAL_ARGS", posargs.join("\n"))
        # Whether completion is being done for a command or a flag.
        putEnv("NODECLIAC_COMP_TYPE", ctype)

        # If completion is for a flag, set flag data for quick access in script.
        if eq(ctype, IDENT_FLG):
            putEnv("NODECLIAC_FLAG_NAME", dflag.flag)
            putEnv("NODECLIAC_FLAG_EQSIGN", dflag.eq)
            putEnv("NODECLIAC_FLAG_VALUE", dflag.value)
            # Indicates if last word is an open quoted value.
            putEnv("NODECLIAC_QUOTE_OPEN", if quote_open: "1" else: "0")

        # Set completion index (index where completion is being attempted) to
        # better mimic bash's $COMP_CWORD builtin variable.
        putEnv("NODECLIAC_COMP_INDEX", (
            if lastchar == C_NULLB or
            (last.len > 0 and (
                last[0] in C_QUOTES or quote_open or last[^2] == C_ESCAPE
            )): $(l - 1) else: $l
        ))
        # Also, ensure NODECLIAC_PREV is reset to the second last argument
        # if it exists only when the lastchar is empty to To better mimic
        # prev=${COMP_WORDS[COMP_CWORD-1]}.
        if lastchar == C_NULLB and l > l - 2: putEnv("NODECLIAC_PREV", args[l - 2])

        # Add parsed arguments as individual env variables.
        for i, arg in args: putEnv("NODECLIAC_ARG_" & $i, arg)

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
        if not strset(input): return

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
            if not strset(input): return

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
                        if c in C_FLAG_DELS and eqsign == -1 and
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
            lastchar = if not (c != C_SPACE and p != C_ESCAPE): c else: C_NULLB

        let ranges = fn_argslices()

        # Using the found argument ranges, create strings of them.
        args = newSeqOfCap[string](ranges.len)
        for rng in ranges:
            let prefix = if rng[3] == 1: "-" else: ""
            args.add(strfromrange(input, rng[0], rng[1], prefix))
            ameta.add([rng[2], 0])

    # Looks for the first row in acdef that matches the provided
    #     command chain. This is a non regex alternative to
    #     re.findBounds(re"^$1[^ ]* ")
    #
    # @param  {string} s - The source string.
    # @param  {string} sub - The needle to find.
    # @return {array} - The range of the command chain row.
    proc lookupcmd(s, sub: string): Range =
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
    #     is a non regex alternative to re.findBounds(re"^$1(.+)$")
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
                        rng[1] - 1] # +1 and -1 to unquote.
        return [-1, 0]

    # Compare string (last) to the execCommand output. Returns true when
    #     output contains the (last) string. This is a non regex alternative
    #     to re.findBounds.
    #
    # @param  {seq} lines - The output lines.
    # @param  {string} sub - The needle to find.
    # @return {bool} - Whether output (lines) contain (last) word.
    proc cmpexecout(lines: seq[string], sub: string): bool =
        for i, line in lines:
            block innerLoop:
                if not strset(line): continue
                let offset = (line[0] == C_EXPOINT).int
                if line.len != sub.len + offset: continue

                for i in countup(offset, line.high):
                    if line[i] != sub[i - offset]: break innerLoop

                return true
        return false

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

        # Note: Track the times ameta gets pruned. This happens when a
        # flag and a next item are merged. This results in the ameta array
        # getting shorted by one, which will then cause for the main loop
        # index to lose sync. To remedy this, the amount of deletions are
        # deducted from the loop index when accessing the ameta array.
        var mc = 0 # ameta merge count.
        var i = 1; while i < l:
            var item = args[i]
            let nitem = if i + 1 < l: args[i + 1] else: ""

            # # Skip quoted or escaped items.
            # if item[0] in C_QUOTES or C_ESCAPE in item:
            #     posargs.add(item)
            #     cargs.add(item)
            #     inc(i)
            #     continue

            if item[0] != C_HYPHEN:
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
                if ameta[i - mc][0] > -1:
                    cargs.add(item)

                    let flag = item[0 .. ameta[i - mc][0] - 1]
                    let value = item[ameta[i - mc][0] .. item.high]
                    trackusedflag(flag, value)
                    trackflagcount(flag)

                    inc(i); continue

                let flag = fn_validate_flag(item)
                let rng = acdef.lookupflg(chainstring, start = bound)
                # Determine whether flag is a boolean flag.
                if acdef.rfind(flag & "?", rng[0], last = rng[1]) > 0:
                    cargs.add(flag)
                    ameta[i - mc][1] = 1
                    trackvaluelessflag(flag)

                else:
                    if strset(nitem) and nitem[0] != C_HYPHEN:
                        let vitem = flag & "=" & nitem
                        cargs.add(vitem)
                        ameta[i - mc][0] = flag.len
                        # Shorten due to merging flag/value.
                        ameta.setLen(ameta.high)
                        inc(mc) # Increment merge count.

                        trackusedflag(flag, nitem)

                        inc(i)
                    else:

                        # Check whether flag needs to be normalized.
                        # For example, the following input:
                        # 'nodecliac print --command [TAB]'
                        # will gets converted into:
                        # 'nodecliac print --command=[TAB]'
                        if (i == args.high) and lastchar == C_SPACE:
                            let aflag = flag & "="
                            # last = aflag
                            lastchar = C_NULLB
                            cargs.add(aflag)
                            args[i] = aflag
                            ameta[i - mc][0] = flag.len
                        else:
                            cargs.add(flag)

                        trackvaluelessflag(flag)

                trackflagcount(flag)

            inc(i)

        # Perform final reset(s).
        last = if lastchar == C_SPACE: "" else: cargs[^1]
        # Reset if completion is being attempted for a quoted/escaped string.
        if lastchar == C_SPACE and cargs.len > 0:
            let litem = cargs[^1]
            quote_open = quote_open and litem[0] == C_HYPHEN
            # Skip single letter sub-commands like in input: '$ nim c '
            if litem.len > 2 and (litem[0] in C_QUOTES or
                quote_open or litem[^2] == C_ESCAPE):
                last = litem
        if last.find(C_QUOTES) == 0: isquoted = true

    # Lookup acdef definitions.
    #
    # @return - Nothing is returned.
    proc fn_lookup(): string =
        # if isquoted or not autocompletion: return ""

        if last.startsWith(C_HYPHEN):
            comptype = "flag"

            let letter = if strset(commandchain): commandchain[1] else: C_UNDERSCORE
            if not strset(commandchain):
                commandchain.setLen(1); commandchain[0] = C_UNDERSCORE

            const def = [-1, -1]
            let frange = (try: db_dict[letter][commandchain] except: [def, def])[1]
            if frange[0] != -1:
                var excluded = initTable[string, int]()
                var parsedflags = initTable[string, int]()
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
                    flag_list = readFile(hdir & "/.nodecliac/registry/" &
                            maincommand & "/placeholders/" & cplname)

                if eq(flag_list, "--"): return ""

                # Split by unescaped pipe '|' characters:
                var flags = flag_list.splitundel(C_PIPE)

                # Context string logic: start ----------------------------------

                let cchain = if eq(commandchain, "_"): "" else: quotemeta(commandchain)
                let rng = acdef.lookupkw(cchain, 1)
                if rng[0] != -1:
                    let context = acdef[rng[0] .. rng[1]]

                    let ctxs = context.split(C_SEMICOLON)
                    for ctx in ctxs:
                        var ctx = ctx.multiReplace([(" ", ""), ("\t", "")])
                        if not strset(ctx): continue
                        if ctx[0] == C_LCURLY and ctx[^1] == C_RCURLY: # Mutual exclusion.
                            ctx = ctx.strip(chars = {C_LCURLY, C_RCURLY})
                            let flags = map(ctx.split(C_PIPE), proc (
                                    x: string): string =
                                (if x.len == 1: "-" else: "--") & x
                            )
                            var exclude: string
                            for flag in flags:
                                if flag in usedflags_counts:
                                    exclude = flag
                                    break
                            if strset(exclude):
                                for flag in flags:
                                    if neq(exclude, flag): excluded[flag] = 1
                                excluded.del(exclude)
                        else:
                            var r = false
                            if C_COLON in ctx:
                                let parts = ctx.split(C_COLON)
                                let flags = parts[0].split(C_COMMA)
                                let conditions = parts[1].split(C_COMMA)
                                # Examples:
                                # flags:      !help,!version
                                # conditions: #fge1, #ale4, !#fge0, !flag-name
                                # [TODO?] index-conditions: 1follow, 1!follow
                                for condition in conditions:
                                    var invert = false
                                    var condition = condition
                                    # Check for inversion.
                                    if condition[0] == C_EXPOINT:
                                        discard shift(condition)
                                        invert = true

                                    let fchar = condition[0]
                                    if fchar == C_NUMSIGN:
                                        let operator = condition[2 .. 3]
                                        let n = condition[4 .. ^1].parseInt()
                                        var c = 0
                                        if condition[1] == C_LF:
                                            c = usedflags_counts.len
                                            # Account for used '--' flag.
                                            if c == 1 and "--" in usedflags_counts: c = 0
                                            if lastchar == C_NULLB: dec(c)
                                        else: c = posargs.len
                                        case (operator):
                                        of "eq": r = c == n
                                        of "ne": r = c != n
                                        of "gt": r = c >  n
                                        of "ge": r = c >= n
                                        of "lt": r = c <  n
                                        of "le": r = c <= n
                                        else: discard
                                        if invert: r = not r
                                    # elif fchar in {'1'..'9'}: continue # [TODO?]
                                    else: # Just a flag name.
                                        if fchar == C_EXPOINT:
                                            if condition in usedflags_counts: r = false
                                        else:
                                            if condition in usedflags_counts: r = true
                                    # Once any condition fails exit loop.
                                    if r == false: break
                                if r == true:
                                    for flag in flags:
                                        var flag = flag
                                        let fchar = flag[0]
                                        flag = flag.strip(chars = {C_EXPOINT})
                                        flag = (if flag.len == 1: "-" else: "--") & flag
                                        if fchar == C_EXPOINT: excluded[flag] = 1
                                        else: excluded.del(flag)
                            else: # Just a flag name.
                                if ctx[0] == C_EXPOINT:
                                    if ctx in usedflags_counts: r = false
                                else:
                                    if ctx in usedflags_counts: r = true
                                if r == true:
                                    var flag = ctx
                                    let fchar = flag[0]
                                    flag = flag.strip(chars = {C_EXPOINT})
                                    flag = (if flag.len == 1: "-" else: "--") & flag
                                    if fchar == C_EXPOINT: excluded[flag] = 1
                                    else: excluded.del(flag)

                # Context string logic: end ------------------------------------

                var
                    last_fkey = last
                    last_value, last_eqsign: string

                let eqsign_index = ameta[^1][0]
                if eqsign_index != -1:
                    last_fkey = last[0 ..< eqsign_index]
                    last_value = last[eqsign_index + 1 .. last.high]

                    last_eqsign = $C_EQUALSIGN

                let last_val_quoted = last_value.len > 0 and
                    last_value[0] in C_QUOTES

                # Store data for env variables.
                dflag = (last_fkey, last_value, last_eqsign)

                # Process flags.
                var i = 0; while i < flags.len:
                    var flag_fkey = flags[i]

                    if not flag_fkey.startsWith(last_fkey): inc(i); continue

                    var
                        flag_eqsign, flag_multif: bool
                        flag_value, cflag: string

                    # If flag contains an eq sign.
                    let eqsign_index = flag_fkey.find(C_EQUALSIGN)
                    if eqsign_index != -1:
                        flag_value = flag_fkey[eqsign_index + 1 .. flag_fkey.high]
                        flag_fkey.setLen(eqsign_index)
                        flag_eqsign = true

                        if flag_fkey[^1] == C_QMARK: discard chop(flag_fkey)
                        # Skip flag if it's mutually exclusivity.
                        if flag_fkey in excluded: inc(i); continue

                        if strset(flag_value) and flag_value[0] == C_ASTERISK:
                            flag_multif = true
                            flag_value.setLen(flag_value.high)

                            # Track multi-starred flags.
                            usedflags_multi[flag_fkey] = 1

                        # Create completion flag item.
                        cflag = flag_fkey & "=" & flag_value

                        # If a command-flag, run it and add items to array.
                        if flag_value[0] == C_DOLLARSIGN and
                            flag_value[1] == C_LPAREN and
                            flag_value[^1] == C_RPAREN and
                            eq(last_eqsign, $C_EQUALSIGN):
                            comptype = "flag;nocache"
                            for line in execCommand(flag_value):
                                if strset(line): flags.add(last_fkey & "=" & line)
                            # Don't add literal command to completions.
                            inc(i)
                            continue

                        # Store for later checks.
                        parsedflags[cflag] = 1
                    else:
                        if flag_fkey[^1] == C_QMARK: discard chop(flag_fkey)
                        # Skip flag if it's mutually exclusivity.
                        if flag_fkey in excluded: inc(i); continue

                        # Create completion flag item.
                        cflag = flag_fkey
                        # Store for later checks.
                        parsedflags[cflag] = 1

                    # If the last flag/word does not have an eq-sign, skip flags
                    # with values as it's pointless to parse them. Basically, if
                    # the last word is not in the form "--form= + a character",
                    # don't show flags with values (--flag=value).
                    if not strset(last_eqsign) and strset(flag_value) and
                        not flag_multif:
                        inc(i)
                        continue

                    # [Start] Remove duplicate flag logic ----------------------

                    var dupe = 0

                    # Let multi-flags through.
                    if flag_fkey in usedflags_multi:

                        # Check if multi-starred flag value has been used.
                        if strset(flag_value):
                            # Add flag to usedflags root level.
                            if flag_fkey notin usedflags:
                                usedflags[flag_fkey] = initTable[string, int]()
                            if flag_value in usedflags[flag_fkey]: dupe = 1

                    elif not flag_eqsign:

                        # Valueless --flag (no-value) dupe check.
                        if flag_fkey in usedflags_valueless or
                        # Check if flag was used with a value already.
                            (flag_fkey in usedflags and
                            usedflags_counts[flag_fkey] < 2 and
                            lastchar == C_NULLB): dupe = 1

                    else: # --flag=<value> (with value) dupe check.

                        # If usedflags contains <flag:value> at root level.
                        if flag_fkey in usedflags:
                            # If no values exists.
                            if not strset(flag_value): dupe = 1 # subl -n 2, subl -n 23

                            else:
                                # Add flag to usedflags root level.
                                if flag_fkey notin usedflags:
                                    usedflags[flag_fkey] = initTable[string, int]()
                                if flag_value in usedflags[flag_fkey]:
                                    dupe = 1 # subl -n 23 -n
                                elif flag_fkey in usedflags_counts:
                                    if usedflags_counts[flag_fkey] > 1: dupe = 1

                        # If no root level entry.
                        else:
                            if neq(last, flag_fkey) and flag_fkey in usedflags_valueless:
                                # Add flag to usedflags root level.
                                if flag_fkey notin usedflags:
                                    usedflags[flag_fkey] = initTable[string, int]()
                                if flag_value notin usedflags[flag_fkey]:
                                    dupe = 1 # subl --type=, subl --type= --

                    if dupe == 1: inc(i); continue # Skip if dupe.

                    # [End] Remove duplicate flag logic ------------------------

                    # Note: Don't list single letter flags. Listing them along
                    # with double hyphen flags is awkward. Therefore, only list
                    # them when completing or showing its value(s).
                    # [https://scripter.co/notes/nim/#from-string]
                    if not singletons and flag_fkey.len == 2 and not strset(flag_value):
                        inc(i); continue

                    # If last word is in the form '--flag=', remove the last
                    # word from the flag to only return its option/value.
                    if strset(last_eqsign):
                        if not flag_value.startsWith(last_value) or not strset(flag_value): inc(i); continue
                        cflag = flag_value

                    # Don't add multi-starred flag item as its non-starred
                    # counterpart has already been added.
                    if flag_multif: inc(i); continue

                    completions.add(cflag)

                    inc(i)

                # Account for quoted strings. Add trailing quote if needed.
                if last_val_quoted:
                    let quote = last_value[0]
                    if last_value[^1] != quote: last_value &= $quote

                    # Add quoted indicator to later escape double quoted strings.
                    comptype = "flag;quoted"
                    if quote == C_DQUOTE: comptype &= ";noescape"

                    # If value is empty return.
                    if last_value.len == 2:
                        completions.add($quote & $quote)
                        return ""

                # If no completions, add last item so Bash compl. can add a space.
                if emp(completions):
                    let key = last_fkey & (if not strset(last_value): "" else: "=" & last_value)
                    let item = if not strset(last_value): last else: last_value
                    if key in parsedflags and (strset(last_value) or not last.endsWith(C_EQUALSIGN)):
                        completions.add(item)
                else:
                    # Note: If the last word (the flag in this case) is an options
                    # flag (i.e. --flag=val) we need to remove the possibly already
                    # used value. For example take the following scenario. Say we
                    # are completing the following flag '--flag=7' and our two
                    # options are '7' and '77'. Since '7' is already used we remove
                    # that value to leave '77' so that on the next tab it can be
                    # completed to '--flag=77'.
                    if strset(last_value) and completions.len >= 2:
                        var last_val_length = last_value.len
                        # Remove values same length as current value.
                        completions = filter(completions, proc (x: string): bool =
                            x.len != last_val_length
                        )

        else:

            comptype = "command"

            # # If command chain and used flags exits, don't complete.
            # if usedflags.len > 0 and strset(commandchain):
            #     commandchain = if not strset(last): "" else: last

            # If no cc get first level commands.
            if not strset(commandchain) and not strset(last):
                if emp(posargs) and 1 in db_levels:
                    completions = toSeq(db_levels[1].keys)
            else:
                let letter = if strset(commandchain): commandchain[1] else: C_UNDERSCORE
                # Letter must exist in dictionary.
                if letter notin db_dict: return ""
                var rows = toSeq(db_dict[letter].keys)
                let lastchar_notspace = lastchar != C_SPACE

                if emp(rows): return ""

                # When there is only 1 completion item and it's the last command
                # in the command chain, clear the completions array to not re-add
                # the same command.
                # if (rows.len == 1 and commandchain.endsWith(rows[0])): rows.setLen(0)

                var usedcommands = initTable[string, int]()
                let level = commandchain.splitundel(C_DOT).high +
                    # Increment level if completing a new command level.
                    (if lastchar == C_SPACE: 1 else: 0)

                # If level does not match argument length, return. As the
                # parsed arguments do not match that of a valid commandchain.
                let la = (cargs.len + 1) - usedflags_counts.len
                if not ((la == level + 1 and lastchar != C_NULLB) or
                    (la > level and lastchar != C_NULLB) or (la - level > 1)):

                    for row in rows:
                        let crange = db_dict[letter][row][0]
                        let cmds = splitundel(acdef[crange[0] .. crange[1]], C_DOT)
                        let cmd = if level < cmds.len: cmds[level] else: ""

                        # Add last command if not yet already added.
                        if not strset(cmd) or cmd in usedcommands: continue
                        # If char before caret isn't a space, completing a command.
                        if lastchar_notspace:
                            if cmd.startsWith(last):
                                let c = commandchain.endsWith("." & cmd)
                                if (not c or (c and lastchar == C_NULLB)) or
                                emp(posargs) and lastchar == C_NULLB:
                                    completions.add(cmd)
                        else: completions.add(cmd) # Allow all.

                        usedcommands[cmd] = 1

            # Note: If only 1 completion exists, check if command exists in
            # commandchain. If so, it's already used so clear completions.
            if nextchar != C_NULLB and completions.len == 1:
                # [TODO] Make test for following case.
                # Code is ugly but only creates a single test string.
                var needle = newStringOfCap(completions[0].len + 2)
                needle.add(".")
                needle.add(completions[0])
                needle.add(".")
                if commandchain.find(needle) != -1: completions.setLen(0)
                else:
                    needle.setLen(needle.high)
                    if commandchain.endsWith(needle): completions.setLen(0)

            # Run default command if no completions were found.
            if emp(completions):
                var copy_commandchain = commandchain

                # Loop over command chains to build individual chain levels.
                while strset(copy_commandchain):
                    # Get command-string, parse and run it.
                    let crange = db_defaults.getOrDefault(copy_commandchain, [-1, -1])
                    var command_str = (
                        if crange != [-1, -1]: acdef[crange[0] .. crange[1]]
                        else: ""
                    )

                    if strset(command_str):
                        let lchar = chop(command_str)

                        # Run command string.
                        if command_str[0] == C_DOLLARSIGN and
                            command_str[1] == C_LPAREN and lchar == C_RPAREN:
                            discard shift(command_str, 1)
                            let lines = execCommand(command_str)
                            for line in lines:
                                if not strset(line): continue
                                if strset(last):
                                    if line.startsWith(last):
                                        completions.add(line)
                                else:
                                    if line.startsWith(C_EXPOINT):
                                        continue
                                    completions.add(line)

                            # If no completions and last word is a valid completion
                            # item, add it to completions to add a trailing space.
                            if emp(completions):
                                # [TODO] Make test for following case.
                                if cmpexecout(lines, last): completions.add(last)

                        # Static value.
                        else:
                            command_str &= lchar

                            if strset(last):
                                # Must start with command.
                                if command_str.startsWith(last):
                                    completions.add(command_str)
                            else: completions.add(command_str)

                        comptype &= ";nocache"
                        break # Stop once a command-string is found/ran.

                    # Remove last command chain from overall command chain.
                    copy_commandchain.setLen(rlastundel(copy_commandchain))

        # Get filedir of command chain.
        if emp(completions):
            let rng = acdef.lookupkw(commandchain, 2)
            if rng[0] != -1: filedir = acdef[rng[0] .. rng[1]]

        # Run posthook if it exists.
        if strset(posthook):
            setEnvs(post = true)
            var res = (try: execProcess(posthook) except: "").string
            res.stripLineEnd()
            var lines = splitLines(res)
            if lines.len == 1 and not strset(lines[0]): lines.setLen(0)

            if not emp(lines):
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

                if emp(completions) and isDSL:
                    for i in countup(0, useditems.high):
                        if not useditems[i].startsWith(last): continue
                        if isDSL and useditems[i].len >= l:
                            useditems[i].delete(0, eqsign_index)
                        completions.add(useditems[i])

    # Send all possible completions to bash.
    proc fn_print() =
        const sep = "\n"
        var skip_map = false
        let isflag = comptype.startsWith(C_LF)
        let iscommand = not isflag
        let lines = comptype & ":" & last & "+" & filedir

        # Note: When providing flag completions and only "--" is provided,
        # collapse (don't show) flags with the same prefix. This aims to
        # help reduce the `display all n possibilities? (y or n)` message
        # prompt. Instead, only show the prefix in the following format:
        # "--prefix..." along with the shortest completion item.
        if completions.len >= 10 and not iscommand and eq(last, "--"):
            # Get completion's common prefixes.
            let res = lcp(
                completions,
                charloop_startindex = 2,
                min_frqz_prefix_len = 2,
                min_prefix_len = 3,
                min_frqz_count = 3,
                char_break_points = [C_EQUALSIGN],
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
                return not (index in rm_indices and rm_indices[index])
            )

            # Add prefix stubs to completions array.
            completions = concat(completions, res.prefixes)

        # When for example, completing 'nodecliac print --command' we remove
        # the first and only completion item's '='. This is better suited for
        # CLI programs that implement/allow for a colon ':' separator. Maybe
        # something that should be opted for via an acmap setting?
        if completions.len == 1 and not iscommand:
            proc completingfv(s: string): bool =
                runnableExamples:
                    doAssert completingfv("--flag") == false
                    doAssert completingfv("--flag=") == true
                    doAssert completingfv("--fla=") == true
                    doAssert completingfv("--fl=") == true
                    doAssert completingfv("--fl=") == true
                    doAssert completingfv("--f=") == true
                    doAssert completingfv("-f=") == true
                    doAssert completingfv("-f") == false
                    doAssert completingfv("--=") == false
                    doAssert completingfv("-=") == false

                if s.len < 3: return
                if s[0] != C_HYPHEN or s[^1] != C_EQUALSIGN: return
                let start = 1 + (s[1] == C_HYPHEN).int
                if start == 2 and s.len < 4: return
                for i in countup(start, s.high - 1):
                    if s[i] notin C_VALID_FLG: return
                return true

            # [TODO] Make test for following case.
            if completingfv(completions[0]) and neq(last, completions[0]) and
                    ((completions[0].len - last.len) > 1):
                discard chop(completions[0])
                completions[0] = "\n" & completions[0]
                skip_map = true

        if not skip_map:
            # Loop over completions and append to list.
            completions = map(completions, proc (x: string): string =
                # Add trailing space to all completions except to flag
                # completions that end with a trailing eq sign, commands
                # that have trailing characters (commands that are being
                # completed in the middle), and flag string completions
                # (i.e. --flag="some-word...).
                let final_space = if isflag and not x.endsWith(C_EQUALSIGN) and
                    x.find(C_QUOTES) != 0 and nextchar == C_NULLB: " " else: ""

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
            var s, sub: string

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
        if not strset(commandchain): # First level commands only.
            if not strset(last):
                db_levels[LVL1] = initTable[string, int]()

                for rng in ranges:
                    let start = rng[0]
                    let stop = rng[1]

                    if acdef[start] == C_SPACE or start > stop : continue

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
                # if lastchar == C_SPACE and not chain.cmpstart(commandchain, C_STR_DOT):
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

    fn_ranges();fn_tokenize();fn_analyze();fn_makedb();discard fn_lookup();fn_print()

main()
