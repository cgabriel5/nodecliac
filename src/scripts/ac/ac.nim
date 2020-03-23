#!/usr/bin/env nim

import streams
from strformat import fmt
from osproc import execProcess
from re import re, `=~`, find, split, replace, contains,
    replacef, reMultiLine, findBounds
from sequtils import map, mapIt, toSeq, concat, filter
from tables import `$`, add, del, len, keys, `[]`, `[]=`, pairs,
    Table, hasKey, values, toTable, initTable, initOrderedTable
from os import getEnv, putEnv, paramStr, paramCount
from strutils import find, join, split, strip, delete, Digits, Letters,
    replace, contains, endsWith, intToStr, parseInt, splitLines, startsWith,
    removePrefix, allCharsInSet

import utils/lcp

if os.paramCount() == 0: quit()

let oinput = os.paramStr(1) # Original unmodified CLI input.
let cline = os.paramStr(2) # CLI input (could be modified via pre-parse).
let cpoint = os.paramStr(3).parseInt(); # Caret index when [tab] key was pressed.
let maincommand = os.paramStr(4) # Get command name from sourced passed-in argument.
let acdef = os.paramStr(5) # Get the acdef definitions file.

var args: seq[string] = @[]
var last = ""
var `type` = ""
var foundflags: seq[string] = @[]
var completions: seq[string] = @[]
var commandchain = ""
var lastchar: char # Character before caret.
let nextchar = cline.substr(cpoint, cpoint) # Character after caret.
var cline_length = cline.len # Original input's length.
var isquoted = false
var autocompletion = true
var input = cline.substr(0, cpoint - 1) # CLI input from start to caret index.
var input_remainder = cline.substr(cpoint, -1)# CLI input from caret index to input string end.
let hdir = os.getEnv("HOME")

var db_dict = initTable[char, Table[string, Table[string, seq[string]]]]()
var db_levels = initTable[int, Table[string, int]]()
var db_fallbacks = initTable[string, string]()

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

# # Log local variables and their values.
# proc fn_debug() =
#     echo "\n  commandchain: '" & $(commandchain) & "'"
#     echo "          last: '" & $(last) & "'"
#     echo "         input: '" & $(input) & "'"
#     echo "  input length: '" & $(cline_length) & "'"
#     echo "   caret index: '" & $(cpoint) & "'"
#     echo "      lastchar: '" & $(lastchar) & "'"
#     echo "      nextchar: '" & $(nextchar) & "'"
#     echo "      isquoted: '" & $(isquoted) & "'"
#     echo "autocompletion: '" & $(autocompletion) & "'"

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

# ---------------------------------------------------------------- SEQ-FUNCTIONS

# Return item at index. Return empty string when out of bounds.
#
# @param  {sequence} sequence - The sequence to use.
# @param  {index} position - The item's index.
# @return {string} - The item at the index.
proc seqItem(sequence: seq, position: int = -1): string =
    let l = sequence.len
    var i = position
    let ispositive = i >= 0
    i = abs(i)

    if l == 0: return ""
    elif ispositive:
        if i > l - 1: return ""
    else:
        if i > l: return ""
        i = l - i
    return $(sequence[i])

# ------------------------------------------------------------------------------

# Predefine procs to maintain proc order with ac.pl.
proc parseCmdStr(input: var string): seq[string]
proc setEnvs(arguments: varargs[string])

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
                command &= " \"$(" & qchar & arg & qchar & ")\""
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
proc setEnvs(arguments: varargs[string]) =
    let l = args.len

    var envs = {
        # nodecliac exposed Bash env vars.

        fmt"{prefix}COMP_LINE": cline, # Original (unmodified) CLI input.
        # Caret index when [tab] key was pressed.
        fmt"{prefix}COMP_POINT": intToStr(cpoint),

        # nodecliac env vars.

        # The command auto completion is being performed for.
        fmt"{prefix}MAIN_COMMAND": maincommand,
        fmt"{prefix}COMMAND_CHAIN": commandchain, # The parsed command chain.
        # fmt"{prefix}USED_FLAGS": usedflags, # The parsed used flags.
        # The last parsed word item (note: could be a partial word item.
        # This happens when the [tab] key gets pressed within a word item.
        # For example, take the input 'maincommand command'. If
        # the [tab] key was pressed like so: 'maincommand comm[tab]and' then
        # the last word item is 'comm' and it is a partial as its remaining
        # text is 'and'. This will result in using 'comm' to determine
        # possible auto completion word possibilities.).
        fmt"{prefix}LAST": last,
        fmt"{prefix}PREV": args[^2], # The word item preceding last word item.
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
        fmt"{prefix}USED_DEFAULT_POSITIONAL_ARGS": used_default_pa_args
    }.toTable

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
proc fn_parser() =
    var argument = ""
    var qchar: char
    var input = input
    var c, p: char

    if input == "": return

    # Spreads input, ex: '-n5 -abc "val"' => '-n 5 -a -b -c "val"'
    #
    # @param  {string} argument - The string to spread.
    # @return {string} - The remaining argument.
    proc spread(argument: var string): string =
        if argument.len >= 3 and argument[1] != '-':
            discard shift(argument)
            let lchar = argument[^1]

            if lchar in "1234567890":
                let argletter = argument[0]
                discard shift(argument)
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

                args.add(if not argument.startsWith('-'): argument else: spread(argument))
                argument = ""
                qchar = '\0'

        else:
            if c in C_QUOTES and p != '\\':
                qchar = c
                argument &= $c

            elif c in C_SPACES and p != '\\':
                if argument == "": continue

                args.add(if not argument.startsWith('-'): argument else: spread(argument))
                argument = ""
                qchar = '\0'
            else: argument &= $c

    # Get last argument.
    if argument != "": args.add(if not argument.startsWith('-'): argument else: spread(argument))
    # Get last char of input.
    lastchar = if not (c != ' ' and p != '\\'): c else: '\0'

# Determine command chain, used flags, and set needed variables.
#
# @return - Nothing is returned.
proc fn_extractor() =
    var l = args.len
    var oldchains: seq[string] = @[]
    var last_valid_chain = ""
    var collect_used_pa_args = false
    var normalized = initTable[int, int]()

    var i = 1; while i < l:
        var item = args[i]
        var nitem = seqItem(args, i + 1)

        # Skip quoted or escaped items.
        if item[0] in C_QUOTES or '\\' in item: inc(i); continue

        if not item.startsWith('-'):
            if collect_used_pa_args:
                used_default_pa_args &= item & "\n"
                inc(i); continue

            commandchain &= "." & fn_normalize_command(item)

            # Validate command chain.
            let pattern = "^" & quotemeta(commandchain) & "[^ ]* "
            if findBounds(acdef, re(pattern, {reMultiLine})).first != -1:
                last_valid_chain = commandchain
            else:
                # Revert to last valid chain.
                commandchain = last_valid_chain
                collect_used_pa_args = true
                used_default_pa_args &= item & "\n"

            foundflags.setLen(0)

        else: # Flag...

            # Store to revert if needed.
            if commandchain != "": oldchains.add(commandchain)

            commandchain = ""
            used_default_pa_args = ""
            collect_used_pa_args = false

            # Normalize colons: '--flag:value' to '--flag=value'.
            if not normalized.hasKey(i) and ':' in item:
                let findex = item.find({':', '='})
                if findex > -1:
                    item[findex] = '='
                    args[i] = item
                normalized[i] = 1 # Memoize.

            if '=' in item: foundflags.add(item); inc(i); continue

            var vitem = fn_validate_flag(item)
            var skipflagval = false

            # If next item exists check if it's a value for the current flag
            # or if it's another flag and do the proper actions for both.
            if nitem != "":
                # Normalize colons: '--flag:value' to '--flag=value'.
                if not normalized.hasKey(i) and ':' in nitem:
                    var findex = nitem.find({':', '='})
                    if findex > -1:
                        nitem[findex] = '='
                        args[i] = nitem
                    normalized[i] = 1 # Memoize.

                # If next word is a value (not a flag).
                if not nitem.startsWith('-'):
                    var pattern = "^" & quotemeta(seqItem(oldchains)) & " (.+)$"
                    let (start, `end`) = findBounds(acdef, re(pattern, {reMultiLine}))
                    if start != -1:
                        # If flag is boolean set flag.
                        pattern = item & "\\?(\\||$)"
                        if contains(acdef[start .. `end`], re(pattern)): skipflagval = true

                    # If flag isn't found, add it as its value.
                    if not skipflagval:
                        vitem &= "=" & nitem
                        inc(i)

                    # Boolean flag so add marker.
                    else: args[i] = args[i] & "?"

                foundflags.add(vitem)

            else:
                var pattern = "^" & quotemeta(seqItem(oldchains)) & " (.+)$"
                let (start, `end`) = findBounds(acdef, re(pattern, {reMultiLine}))
                if start != -1:
                    # If flag is boolean set flag.
                    pattern = item & "\\?(\\||$)"
                    if contains(acdef[start .. `end`], re(pattern)): skipflagval = true

                # Boolean flag so add marker.
                if skipflagval: args[i] = args[i] & "?"

                foundflags.add(vitem)

        inc(i)

    # Validate command chain.
    commandchain = fn_validate_command(if commandchain != "": commandchain else: seqItem(oldchains))

    # Determine whether to turn off autocompletion.
    var lword = seqItem(args)
    if lastchar == ' ':
        if lword.startsWith('-'):
            autocompletion = lword.find({'=', '?'}) > -1
    else:
        if not lword.startsWith('-'):
            var sword = seqItem(args, -2)
            if sword.startsWith('-'):
                autocompletion = sword.find({'=', '?'}) > -1

    # Remove boolean markers from flags.
    for i, arg in args:
        var arg = arg
        if arg.startsWith('-') and '=' notin arg and chop(arg) == '?':
            args[i] = arg

    # Set last word.
    last = if lastchar == ' ': "" else: seqItem(args)

    # Check if last word is quoted.
    if last.find(C_QUOTES) == 0: isquoted = true

    # Note: If autocompletion is off check for one of following cases:
    # '$ maincommand --flag ' or '$ maincommand --flag val'. If so, show
    # value options for the flag or complete started value option.
    if not autocompletion and nextchar != "-":
        let islast_aspace = lastchar == ' '
        let nlast = seqItem(args, if islast_aspace: -1 else: -2)
        var pattern = "^" & commandchain & " (.*)$"

        if nlast.startsWith('-') and '=' notin nlast:
            if islast_aspace:
                # Check if flag exists like: '--flag='
                let (start, `end`) = findBounds(acdef, re(pattern, {reMultiLine}))
                if start != -1:
                    # Check if flag exists with option(s).
                    var pattern = nlast & "=(?!\\*).*?(\\||$)"
                    if contains(acdef[start .. `end`], re(pattern)):
                        # Modify last used flag.
                        foundflags[^1] = foundflags[^1] & "="
                        last = nlast & "="
                        lastchar = '='
                        autocompletion = true
            else: # Complete started value option.
                # Check if flag exists like: '--flag='
                let (start, `end`) = findBounds(acdef, re(pattern, {reMultiLine}))
                if start != -1:
                    # Check if flag exists with option(s).
                    var pattern = nlast & "=(" & quotemeta(last) & "|\\$\\().*?(\\||$)"
                    if contains(acdef[start .. `end`], re(pattern)):
                        last = nlast & "=" & last
                        lastchar = last[^1]
                        autocompletion = true

    # Store used flags for later lookup.
    for uflag in foundflags:
        var uflag_fkey = uflag
        var uflag_value = ""

        if '=' in uflag_fkey:
            let eqsign_index = uflag.find('=')
            uflag_fkey = uflag.substr(0, eqsign_index - 1)
            uflag_value = uflag.substr(eqsign_index + 1)

        if uflag_value != "":
            if not usedflags.hasKey(uflag_fkey):
                usedflags[uflag_fkey] = {uflag_value: 1}.toTable
        else: usedflags_valueless[uflag_fkey] = 1

        # Track times flag was used.
        if not usedflags_counts.hasKey(uflag_fkey):
            usedflags_counts[uflag_fkey] = 0
        inc(usedflags_counts[uflag_fkey])

# Lookup acdef definitions.
#
# @return - Nothing is returned.
proc fn_lookup(): string =
    if isquoted or not autocompletion: return ""

    if last.startsWith('-'):
        `type` = "flag"

        var letter = if commandchain != "": commandchain[1] else: '_'
        commandchain = if commandchain != "": commandchain else: "_"
        if db_dict.hasKey(letter) and db_dict[letter].hasKey(commandchain):
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
                    last_value = last_value[0 .. ^1]

                last_eqsign = '='

            let last_val_quoted = last_value.find(C_QUOTES) == 0

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

                    if flag_value.startsWith('*'):
                        flag_multif = '*'
                        flag_value = flag_value[0 .. ^1]

                        # Track multi-starred flags.
                        usedflags_multi[flag_fkey] = 1

                    # Create completion flag item.
                    cflag = fmt"{flag_fkey}={flag_value}"

                    # If a command-flag, run it and add items to array.
                    if flag_value.startsWith("$(") and flag_value.endsWith(')'):
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
                    if usedflags_valueless.hasKey(flag_fkey): dupe = 1

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
                if flag_fkey.len == 2 and flag_value == "": inc(i); continue

                # If last word is in the form '--flag=', remove the last
                # word from the flag to only return its option/value.
                if last_eqsign != '\0':
                    if not flag_value.startsWith(last_value) or flag_value == "": inc(i); continue
                    cflag = flag_value

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
                var key = last_fkey & (if last_value == "": "" else: "=" & last_value)
                var item = if last_value == "": last else: last_value
                if parsedflags.hasKey(key): completions.add(item)
                if completions.len == 0: quit()
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

        # If command chain and used flags exits, don't complete.
        if usedflags.len > 0 and commandchain != "":
            commandchain = if last == "": "" else: last

        # If no cc get first level commands.
        if commandchain == "" and last == "":
            if db_levels.hasKey(1): completions = toSeq(db_levels[1].keys)
        else:
            let letter = if commandchain != "": commandchain[1] else: '_'
            # Letter must exist in dictionary.
            if not db_dict.hasKey(letter): return ""
            var rows = toSeq(db_dict[letter].keys)
            let lastchar_notspace = lastchar != ' '

            if rows.len == 0: return ""

            var usedcommands = initTable[string, int]()
            var commands = (commandchain[0 .. ^1]).split(re"(?<!\\)\.")
            var level = commands.len - 1
            # Increment level if completing a new command level.
            if lastchar == ' ': inc(level)

            # Get commandchains for specific letter outside of loop.
            var h = db_dict[letter]

            for row in rows:
                var row = row
                # Command must exist.
                if not h[row].hasKey("commands"): continue

                var cmds = h[row]["commands"]
                row = if level < cmds.len: cmds[level] else: ""

                # Add last command it not yet already added.
                if row == "" or usedcommands.hasKey(row): continue
                # If char before caret isn't a space, completing a command.
                if lastchar_notspace:
                    if row.startsWith(last): completions.add(row)
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
                var command_str = if db_fallbacks.hasKey(copy_commandchain): db_fallbacks[copy_commandchain] else: ""
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

# Send all possible completions to bash.
proc fn_printer() =
    var lines = fmt"{`type`}:{last}"

    var iscommand = `type`.startsWith('c')
    if iscommand: lines &= "\n"

    var sep = if iscommand: " " else: "\n"
    var isflag_type = `type`.startsWith('f')
    var skip_map = false

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
            let final_space = if isflag_type and not x.endsWith('=') and x.find({'"', '\''}) != 0 and nextchar == "": " " else: ""

            sep & x & final_space
        )

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

            let commands = (chain[0 .. ^1]).split(re"(?<!\\)\.")

            # Cleanup remainder (flag/command-string).
            if ord(line[0]) == 45:
                let fchar = chain[1]
                if not db_dict.hasKey(fchar):
                    db_dict[fchar] = initTable[string, Table[string, seq[string]]]()
                db_dict[fchar][chain] = {"commands": commands, "flags": @[line]}.toTable

            else: # Store fallback.
                if not db_fallbacks.hasKey(chain): db_fallbacks[chain] = line.substr(8)

fn_parser();fn_extractor();fn_makedb();discard fn_lookup();fn_printer()
