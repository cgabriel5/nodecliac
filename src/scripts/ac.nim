#!/usr/bin/env nim

import os
import re
import system
import tables
import osproc
import sequtils
import strutils
import strformat

# If no arguments are passed to script then exit.
if os.paramCount() == 0: quit()

# let hdir = os.getEnv("HOME")

# Get arguments.
# let sourcepath =  os.paramStr(0)
let oinput = os.paramStr(1) # Original unmodified CLI input.
let cline = os.paramStr(2) # CLI input (could be modified via prehook).
let cpoint = os.paramStr(3).parseInt(); # Caret index when [tab] key was pressed.
let maincommand = os.paramStr(4) # Get command name from sourced passed-in argument.
let acdef = os.paramStr(5) # Get the acdef definitions file.

# Vars.
var args: seq[string] = @[]
var last = ""
var ac_type = ""
var foundflags: seq[string] = @[]
var completions: seq[string] = @[]
var commandchain = ""
var lastchar = "" # = $cline.substr(cpoint - 1, 1); # Character before caret.
var nextchar = cline.substr(cpoint, 1) # Character after caret.
var cline_length = cline.len # Original input's length.
var isquoted = false
var autocompletion = true
var input = cline.substr(0, cpoint) # CLI input from start to caret index.
var input_remainder = cline.substr(cpoint, -1) # CLI input from caret index to input string end.

# Vars - ACDEF file parsing variables.
var db_dict = initTable[char, Table[string, Table[string, seq[string]]]]()
var db_levels = initTable[int, Table[string, int]]()
var db_fallbacks = initTable[string, string]()

# Used flags variables.
var usedflags = initTable[string, Table[string, int]]()
var usedflags_valueless = initTable[string, int]()
var usedflags_multi = initTable[string, int]()
var usedflags_counts = initTable[string, int]()

# Vars to be used for storing used default positional arguments.
var used_default_pa_args = ""

# Set environment vars so command has access.
const prefix = "NODECLIAC_"

# [https://nim-lang.org/docs/strutils.html#10]
const valid_cmd_chars = Letters + Digits + {'-', '.', '_', ':', '\\'}
const valid_flg_chars = Letters + Digits + {'-', '_', }

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

# Checks whether the provided string is a valid file or directory.
#
# @param  {string} 1) - The string to check.
# @return {number}    - 0 or 1 to represent boolean.
#
# Test with following commands:
# $ nodecliac uninstall subcmd subcmd noncmd ~ --
# $ nodecliac add ~ --
# $ nodecliac ~ --
proc fn_is_file_or_dir(item: string): bool =
    # If arg contains a '/' sign check if it's a path. If so let it pass.
    return ('/' in item or item == "~")

# Escape '\' characters and replace unescaped slashes '/' with '.' (dots)
#     command strings
#
# @param {string} 1) - The item (command) string to escape.
# @return {string} - The escaped item (command) string.
proc fn_normalize_command(item: var string): string =
    # If string is a file/directory then return.
    if fn_is_file_or_dir(item): return item

    item = item.replacef(re"\.", "\\\\.") # Escape dots.
               .replacef(re"([^\\]|^)\/", "$1.") # Replace unescaped '/' with '.' dots.

    # Finally, validate that only allowed characters are in string.
    if not allCharsInSet(item, valid_cmd_chars): quit()

    # Returned normalized item string.
    return item

# Validates whether command/flag (--flag) only contain valid characters.
#     If word command/flag contains invalid characters the script will
#     exit. In turn, terminating auto completion.
#
# @param {string} 1) - The word to check.
# @return {string} - The validated argument.
proc fn_validate_flag(item: string): string =
    # If string is a file/directory then return.
    if fn_is_file_or_dir(item): return item

    # Finally, validate that only allowed characters are in string.
    if not allCharsInSet(item, valid_flg_chars): quit()

    # Return word.
    return item

# Look at fn_validate_flag for function details.
proc fn_validate_command(item: string): string =
    if fn_is_file_or_dir(item): return item

    # Finally, validate that only allowed characters are in string.
    if not allCharsInSet(item, valid_cmd_chars): quit()

    return item

# START=========================================================HELPER-FUNCTIONS

# Substitute for Perl's chop function. Removes last character of provided
#     string. Nothing is returned as it modifies the original input.
#
# @param  {string} 1) - The string to modify.
# @return {nothing}   - Nothing is returned.
proc fn_chop(input: var string) =
    let l = input.len
    input.delete(l - 1, l)

# Opposite of the chop() function. Same idea but removes the first character
#     of provided input from the start of the string.
#
# @param  {string} 1) - The string to modify.
# @return {nothing}   - Nothing is returned.
proc fn_shift(input: var string) =
    input.delete(0, 0)

# Return last character of provided string.
#
# @param  {string} 1) - The string to use.
# @return {string}    - The last character of string.
proc fn_lastchar(input: string): string =
    return $input[^1]

# Return first character of provided string.
#
# @param  {string} 1) - The string to use.
# @return {string}    - The first character of string.
proc fn_firstchar(input: string): string =
    return $input[0]

# Remove last char from provided string.
#
# @param  {string} 1) - The string to modify.
# @return {string}    - The string after manipulation.
proc fn_rm_lastchar(input: string): string =
    return input.substr(0, input.len - 2)

# Remove last char from provided string.
#
# @param  {string} 1) - The string to modify.
# @return {string}    - The string after manipulation.
proc fn_rm_firstchar(input: string): string =
    # return input.substr(1, input.len - 1)
    return input.substr(1)

# Splits provided string into an its individual characters.
#
# @param  {string} 1) - The provided string to split.
# @return {seq}       - The seq of individual characters.
# @resource [https://stackoverflow.com/a/51160075]
proc fn_split_by_chars(input: string): seq =
    # return str.map(c => c) # ← Requires importing `sugar` module.
    return mapIt(input, it)

# Substitute for Perl's quotemeta function.
#
# @param  {string} 1) - The string to escape.
# @return {string}    - The escaped string.
# @resource [https://perldoc.perl.org/functions/quotemeta.html]
proc fn_quotemeta(input: string): string =
    return multiReplace(input, [(re"([^A-Za-z_0-9])", "\\$1")])

# Joins all provided strings into a single string.
#
# @param  {string} 1) - N amount of arguments (get casted to string if not).
# @return {string}    - The final concatenated string.
# @resource [https://nim-by-example.github.io/varargs/]
# @resource [https://forum.nim-lang.org/t/431]
# @resource [https://www.rosettacode.org/wiki/String_concatenation#Nim]
proc fn_concat_str(strs: varargs[string, `$`]): string =
  var fstring = ""
  for str in strs: fstring &= str
  return fstring

# Get item from provided sequence at provided index.
#
# @param  {sequence} 1) - The sequence to use.
# @param  {index} 2)    - The item's index.
# @return {string}      - The item at the index.
proc fn_last_seq_item(sequence: seq, position: int): string =
    var l = sequence.len
    var i = position # Copy index to another var else nim complains.
    var ispositive = i >= 0 # Check whether index is positive or not.
    i = abs(i) # Make positive.

    # If sequence is empty return.
    if l == 0: return ""

    if ispositive:
        # If the provided index is larger then the max index return.
        if i > l - 1: return ""
    else:
        # If index is larger than the sequence length return.
        if i > l: return ""
        i = l - i # Reset index to get item from the right.

    return $(sequence[i])

# END===========================================================HELPER-FUNCTIONS

# Parse string command flag ($("")) arguments.
#
# @param  {string} 1) input - The string command-flag to parse.
# @return {string} - The cleaned command-flag string.
# proc fn_paramparse(input: var string): seq[string] =
proc fn_paramparse(input: var string): tuple =
    # Parse command string to get individual arguments. Things to note: each
    # argument is to be encapsulated with strings. User can decide which to
    # use, either single or double. As long as their contents are properly
    # escaped.

    # Vars.
    var argument = ""
    # var arguments: seq[string] = @[]
    var args: tuple[count: int, list: seq[string]]
    # var l = input.len
    # var ll = l - 1
    # var args_count = 0
    var qchar = ""
    # Loop character variables (current, previous characters).
    var c = ""
    var p = ""

    # Input must not be empty.
    if input == "":
        args = (count: 0, list: @[""])
        return args

    # Command flag syntax:
    # $("COMMAND-STRING" [, [<ARG1>, <ARGN> [, "<DELIMITER>"]]])

    # Loop over every input char: [https://stackoverflow.com/q/10487316]
    # [https://stackoverflow.com/q/18906514]
    # [https://stackoverflow.com/q/13952870]
    # [https://stackoverflow.com/q/1007981]
    while input != "":
        # Get needed characters.
        c = fn_firstchar(input) # 'Chop' first char from string.
        input = fn_rm_firstchar(input) # Remove the first char from string.
        p = fn_lastchar(argument) # Get last char from argument.

        # qchar is set, grab all chars until an unescaped qchar is hit.
        if qchar == "":
            if c in ["\"", "'"] and p != "\\":
                # Set qchar as the opening quote character.
                qchar = c
                # Capture character.
                argument &= c

            # Continuing will ignore all characters outside of quotes.
            # For example, take the example input string: "'name', 'age'".
            # Since the ", " (minus the quotes) is outside of a quoted
            # region and only serve as a delimiter, they don't need to be
            # captured. This means they can be ignored.
            # next;
        else:
            # Unescape '|' (pipe) characters.
            if c == "|" and p == "\\":
                argument = fn_rm_lastchar(argument) # Remove last escaping slash to unescape pipe.

            # Capture character.
            argument &= c

            if c == qchar and p != "\\":
                # Store argument and reset vars.
                args.list.add(argument)
                args.count = args.count + 1
                # Clear/reset variables.
                argument = ""
                qchar = ""

    # Get last argument.
    if argument != "": args.list.add(argument)

    # Push argument counter to array.
    # args.list.add(args_count)

    # Return args.list array.
    # [https://stackoverflow.com/a/11303607]
    return args

# Set environment variables to access in custom scripts.
#
# @return {undefined} - Nothing is returned.
proc fn_set_envs() =
    # Get parsed arguments count.
    let l = args.len

    # Use hash to store environment variables: [https://perlmaven.com/perl-hashes]
    var envs = {
        # Following env vars are provided by bash but exposed via nodecliac.
        fmt"{prefix}COMP_LINE": cline, # Original (unmodified) CLI input.
        fmt"{prefix}COMP_POINT": intToStr(cpoint), # Caret index when [tab] key was pressed.

        # Following env vars are custom and exposed via nodecliac.
        # fmt"{prefix}ACDEF": acdef,
        fmt"{prefix}MAIN_COMMAND": maincommand, # The command auto completion is being performed for.
        fmt"{prefix}COMMAND_CHAIN": commandchain, # The parsed command chain.
        # fmt"{prefix}USED_FLAGS": usedflags, # The parsed used flags.
        fmt"{prefix}LAST": last, # The last parsed word item (note: could be a partial word item. This happens
        # when the [tab] key gets pressed within a word item. For example, take the input 'maincommand command'. If
        # the [tab] key was pressed like so: 'maincommand comm[tab]and' then the last word item is 'comm' and it is
        # a partial as its remaining text is 'and'. This will result in using 'comm' to determine possible auto
        # completion word possibilities.).
        fmt"{prefix}PREV": args[^2], # The word item preceding the last word item.
        fmt"{prefix}INPUT": input, # CLI input from start to caret index.
        fmt"{prefix}INPUT_ORIGINAL": oinput, # Original unmodified CLI input.
        fmt"{prefix}INPUT_REMAINDER": input_remainder, # CLI input from start to caret index.
        fmt"{prefix}LAST_CHAR": lastchar, # Character before caret.
        fmt"{prefix}NEXT_CHAR": nextchar, # Character after caret. If char is not '' (empty) then the last word
        # item is a partial word.
        fmt"{prefix}COMP_LINE_LENGTH": intToStr(cline_length), # Original input's length.
        fmt"{prefix}INPUT_LINE_LENGTH": intToStr(cline_length), # CLI input from start to caret index string length.
        fmt"{prefix}ARG_COUNT": intToStr(l), # Amount arguments parsed before caret position/index.
        # Store collected positional arguments after validating the command-chain to access in plugin auto-completion scripts.
        fmt"{prefix}USED_DEFAULT_POSITIONAL_ARGS": used_default_pa_args
    }.toTable

    # Dynamically set arguments.
    # for (my $i = 0; $i < $l; $i++) { $ENV{"${prefix}ARG_${i}"} = $args[$i]; }

    # If no arguments are provided then we set all env variables.
    # [https://stackoverflow.com/a/19234273]
    # [https://alvinalexander.com/blog/post/perl/how-access-arguments-perl-subroutine-function]
    # if @_ == 0:
    # Set environment variable: [https://alvinalexander.com/blog/post/perl/how-to-traverse-loop-items-elements-perl-hash]
    for key, value in envs: os.putEnv(key, value) # [https://nim-lang.org/docs/os.html#putEnv%2Cstring%2Cstring]
    # else:
    #     # Split rows by lines: [https://stackoverflow.com/a/11746174]
    #     for env_name @_:
    #         key = "${prefix}$env_name"
    #         # Set environment if provided env name exists in envs lookup hash table.
    #         # [https://alvinalexander.com/blog/post/perl/perl-how-test-hash-contains-key]
    #         if exists($envs{$key})): $ENV{$key} = $envs{$key}

# This is for future reference on how to escape code for the shell,
# bash -c command, and a Perl one-liner. The following lines of code
# can be copy/pasted into the terminal.
# [https://stackoverflow.com/a/20796575]
# [https://stackoverflow.com/questions/17420994/bash-regex-match-string]
# perl -e 'print `bash -c "for f in ~/.nodecliac/registry/yarn/hooks/*.*; do [[ \\\"\\\${f##*/}\\\" =~ ^(acdef|input)\\.[a-zA-Z]+\$ ]] && echo \"\\\$f\"; done;"`';
#                 bash -c "for f in ~/.nodecliac/registry/yarn/hooks/*.*; do [[ \"\${f##*/}\" =~ ^(acdef|input)\\.[a-zA-Z]+$ ]] && echo \"\$f\"; done;"
#                          for f in ~/.nodecliac/registry/yarn/hooks/*.*; do [[ "${f##*/}" =~ ^(acdef|input)\.[a-zA-Z]+$ ]] && echo "$f"; done

# Parse and run command-flag (flag) or default command chain command
#     (commandchain).
#
# @param {string} 1) - The command to run in string.
# @return {null} - Nothing is returned.
proc fn_execute_command(command_str: var string , flags: var seq = @[""], last_fkey: string = "") =
    # Cache captured string command.
    var r = fn_paramparse(command_str)
    var arguments = r.list
    let args_count = r.count

    # Set defaults.
    var command = arguments[0]
    # By default command output will be split lines.
    var delimiter = "\\r?\\n"

    # 'bash -c' with arguments documentation:
    # [https://stackoverflow.com/q/26167803]
    # [https://unix.stackexchange.com/a/144519]
    # [https://stackoverflow.com/a/1711985]

    # Start creating command string. Will take the
    # following form: `$command 2> /dev/null`
    var cmd = fn_rm_firstchar(fn_rm_lastchar(command)) # Remove start/end quotes.
    # Same as String.substr(1, String.len - 2)

    # Only command and delimiter.
    if args_count > 1:
        # print last element
        # cdelimiter = arguments[-1]
        var cdelimiter = arguments.pop()

        # Set custom delimiter if provided. To be
        # provided it must be more than 2 characters.
        # Meaning more than the 2 quotes.
        if cdelimiter.len >= 2:
            # [https://stackoverflow.com/a/5745667]
            delimiter = fn_rm_firstchar(fn_rm_lastchar(cdelimiter))

        # Reduce arguments count by one since we
        # popped off the last item (the delimiter).
        # args_count = args_count - 1

        # Add arguments to command string.
        for i in countup(1, args_count - 1, 1):
            # Cache argument.
            var arg = arguments[i]

            # Run command if '$' is prefix to string.
            if arg.startsWith('$'):
                # Remove '$' command indicator.
                arg = fn_rm_firstchar(arg)
                # Get the used quote type.
                var quote_char = fn_firstchar(arg)

                # Remove start/end quotes.
                arg = fn_rm_firstchar(fn_rm_lastchar(arg))

                # Run command and append result to command string.
                var cmdarg = fmt"{arg} 2> /dev/null"
                let res = osproc.execProcess(cmdarg)
                cmd &= " " & quote_char & res & quote_char

                # # If the result is empty after
                # # trimming then do not append?
                # my $result = `$cmdarg`;
                # if ($result =~ s/^\s*|\s*$//rg) {}
            else:
                # Append non-command argument to
                # command string.
                cmd &= " " & arg

    # Close command string. Suppress any/all errors.
    cmd &= " 2> /dev/null"

    # Reset command string.
    command = cmd

    # Run command. Add an or logical statement in case
    # the command returns nothing or an error is return.
    # [https://stackoverflow.com/a/3854742]
    # [https://stackoverflow.com/a/15678831]
    # [https://stackoverflow.com/a/9784016]
    # [https://stackoverflow.com/a/3201234]
    # [https://stackoverflow.com/a/3374285]
    # [https://stackoverflow.com/a/11231972]

    # Set all environment variables to access in custom scripts.
    fn_set_envs()

    # Run the command.
    # var lines = $(os.execShellCmd(command)) # [https://nim-lang.org/docs/os.html]
    var lines = osproc.execProcess(command) # [https://nim-lang.org/docs/osproc.html]

    # Note: command_str (the provided command string) will
    # be injected as is. Meaning it will be provided to
    # 'bash' with the provided surrounding quotes. User
    # needs to make sure to properly use and escape
    # quotes as needed. ' 2> /dev/null' will suppress
    # all errors in the event the command fails.

    # Unset environment vars once command is ran.
    # [https://stackoverflow.com/a/8770380]
    # Is this needed? For example, unset NODECLIAC_INPUT:
    # delete $ENV{"${prefix}INPUT"};

    # By default if the command generates output split
    # it by lines. Unless a delimiter was provided.
    # Then split by custom delimiter to then add to
    # flags array.
    if lines != "":
        # Trim string if using custom delimiter.
        if delimiter != "\\r?\\n":
            # [https://perlmaven.com/trim]
            lines = lines.strip() # [https://www.rosettacode.org/wiki/Strip_whitespace_from_a_string/Top_and_tail#Nim]

        # Split output by lines.
        # [https://stackoverflow.com/a/4226362]
        # var lines = lines.split(delimiter)
        # var lines = split(lines, re(fmt"{delimiter}"))
        var lines = split(lines, re(delimiter))

        # Run logic for command-flag command execution.
        if ac_type == "flag":
            # Add each line to flags array.
            for line in lines:
                # # Remove starting left line break in line,
                # # if it exists, before adding to flags.
                # if delimiter == '$':
                #   line =~ s/^\n//

                # Line cannot be empty.
                if line != "":
                    # Finally, add to flags array.
                    flags.add(last_fkey & "=" & line)
        # Run logic for default command chain commands.
        else:
            # Add each line to completions array.
            for line in lines:
                # Line cannot be empty.
                if line != "":
                    if last != "":
                        # When last word is present only
                        # add words that start with last
                        # word.

                        # Since we are completing a command we only
                        # want words that start with the current
                        # command we are trying to complete.
                        if line.startsWith(last):
                            # Finally, add to flags array.
                            completions.add(line)
                    else:
                        # Finally, add to flags array.
                        completions.add(line)

            # If completions array is still empty then add last word to
            # completions array to append a trailing space.
            if completions.len == 0: completions.add(last)

# ----------------------------------------------------------------MAIN-FUNCTIONS

# Determine command chain, used flags, and set needed variables (i.e.
#     commandchain, autocompletion, last, lastchar, isquoted,
#     collect_used_pa_args, used_default_pa_args).
#
# Test input:
# myapp run example go --global-flag value
# myapp run example go --global-flag value subcommand
# myapp run example go --global-flag value --flag2
# myapp run example go --global-flag value --flag2 value
# myapp run example go --global-flag value --flag2 value subcommand
# myapp run example go --global-flag value --flag2 value subcommand --flag3
# myapp run example go --global-flag --flag2
# myapp run example go --global-flag --flag value subcommand
# myapp run example go --global-flag --flag value subcommand --global-flag --flag value
# myapp run example go --global-flag value subcommand
# myapp run 'some' --flagsin command1 sub1 --flag1 val
# myapp run -rd '' -a config
# myapp --Wno-strict-overflow= config
# myapp run -u $(id -u $USER):$(id -g $USER\ )
# myapp run -u $(id -u $USER):$(id -g $USER )
proc fn_extractor() =
    # Vars.
    var l = args.len
    var oldchains: seq[string] = @[]
    # Following variables are used when validating command chain.
    var last_valid_chain = ""
    var collect_used_pa_args = false

    # Loop over CLI arguments.
    for i in countup(1, l - 1, 1):
        var i = i
        # Cache current loop item.
        var item = args[i]
        # var nitem = args[i + 1]
        var nitem = fn_last_seq_item(args, i + 1)

        # Skip quoted (string) items.
        if fn_firstchar(item) in "\"'": continue # If first char is a quote...

        # Else if the argument is not quoted check if item contains
        # an escape sequences. If so skip the item.
        elif "\\" in item: continue

        # If a command (does not start with a hyphen.)
        # [https://stackoverflow.com/a/34951053]
        # [https://www.thoughtco.com/perl-chr-ord-functions-quick-tutorial-2641190]
        if not item.startsWith('-'): # If not a flag...
            # Store default positional argument if flag is set.
            if collect_used_pa_args:
                used_default_pa_args &= "\n" & item # Add used argument.
                continue # Skip all following logic.

            # Store command.
            commandchain &= "." & fn_normalize_command(item)

            # Check that command chain exists in acdef.
            var pattern = "^" & fn_quotemeta(commandchain) & "[^ ]* "
            var matches = findAll(acdef, re(pattern, {reMultiLine}))
            if matches.len > 0:
                # If there is a match then store chain.
                last_valid_chain = commandchain
            else:
                # Revert command chain back to last valid command chain.
                commandchain = last_valid_chain

                # Set flag to start collecting used positional arguments.
                collect_used_pa_args = true
                # Store used argument.
                used_default_pa_args &= "\n" & item

            # Reset used flags.
            foundflags.setLen(0)
        else: # We have a flag.
            # Store commandchain to revert to it if needed.
            if commandchain != "": oldchains.add(commandchain)
            commandchain = ""

            # Clear stored used default positional arguments string.
            used_default_pa_args = ""
            collect_used_pa_args = false

            # If the flag contains an eq sign don't look ahead.
            if "=" in item:
                foundflags.add(item)
                continue

            # Validate argument.
            var vitem = fn_validate_flag(item)
            # Check whether flag is a boolean:
            var skipflagval = false

            # Look ahead to check if next item exists. If a word
            # exists then we need to check whether is a value option
            # for the current flag or if it's another flag and do
            # the proper actions for both.
            if nitem != "":
                # If the next word is a value...
                if not nitem.startsWith('-'): # If not a flag...
                    # Get flag lists for command from ACDEF.
                    var pattern = "^" & fn_quotemeta(fn_last_seq_item(oldchains, -1)) & " (.+)$"
                    var matches = findAll(acdef, re(pattern, {reMultiLine}))
                    if matches.len > 0:
                        # Check if the item (flag) exists as a boolean
                        # in the flag lists. If so turn on flag.
                        pattern = item & "\\?(\\||$)"
                        if contains(matches[0], re(pattern)): skipflagval = true
                    # If the flag is not found then simply add the
                    # next item as its value.
                    if not skipflagval:
                        vitem &= "=" & nitem

                        # Increase index to skip added flag value.
                        i = i + 1

                    # It's a boolean flag so add boolean marker (?).
                    else: args[i] = args[i] & "?"

                # Add argument (flag) to found flags array.
                foundflags.add(vitem)

            else:
                # Get flag lists for command from ACDEF.
                var pattern = "^" & fn_quotemeta(fn_last_seq_item(oldchains, -1)) & " (.+)$"
                var matches = findAll(acdef, re(pattern, {reMultiLine}))
                if matches.len > 0:
                    # Check if the item (flag) exists as a boolean
                    # in the flag lists. If so turn on flag.
                    pattern = item & "\\?(\\||$)"
                    if contains(matches[0], re(pattern)): skipflagval = true

                # If flag is found then append boolean marker (?).
                if skipflagval: args[i] = args[i] & "?"

                # Add argument (flag) to found flags array.
                foundflags.add(vitem)


    # Create a function which gets the last item of an array and handles when array is negative.

    # Revert commandchain to old chain if empty.
    var value = if commandchain != "": commandchain else: fn_last_seq_item(oldchains, -1)
    commandchain = fn_validate_command(value)

    # Determine whether to turn off autocompletion or not.
    var lword = fn_last_seq_item(args, -1) # Get last word item.
    if lastchar == " ":
        # Must start with a hyphen.
        if lword.startsWith('-'): # If a flag...
            # Turn on for flags with an eq-sign or a boolean indicator (?).
            autocompletion = if lword.find({'=', '?'}) > -1: true else: false
    else:
        # Does not start with a hyphen.
        if not lword.startsWith('-'): # If not a flag...
            var sword = fn_last_seq_item(args, -2) # Get second to last word item.
            # Check if second to last word is a flag.
            if sword.startsWith('-'): # If a flag...
                # Turn on for flags with an eq-sign or a boolean indicator (?).
                autocompletion = if sword.find({'=', '?'}) > -1: true else: false

    # Remove boolean indicator from flags.
    for i, arg in args:
        # If argument starts with a hyphen, does not contain an eq sign, and
        # last character is a boolean - remove boolean indicator and reset the
        # argument in array.
        if arg.startsWith('-') and not ('=' in arg) and fn_lastchar(arg) == "?":
            args[i] = fn_rm_lastchar(arg) # Reset argument to exclude boolean indicator.

    # Set last word. If the last char is a space then the last word
    # will be empty. Else set it to the last word.
    # Switch statement: [https://stackoverflow.com/a/22575299]
    last = if lastchar == " ": "" else: fn_last_seq_item(args, -1)

    # Check whether last word is quoted or not.
    if last.find({'"', '\''}) == 0: isquoted = true

    # Note: If autocompletion is off check whether we have one of the
    # following cases: '$ maincommand --flag ' or '$ maincommand --flag val'.
    # If we do then we show the possible value options for the flag or
    # try and complete the currently started value option.
    if not autocompletion and nextchar != "-":
        var islast_aspace = lastchar == " "
        # Get correct last word.
        var nlast = fn_last_seq_item(args, if islast_aspace: -1 else: -2)
        # acdef commandchain lookup Regex.
        var pattern = "^" & commandchain & " (.*)$"

        # The last word (either last or second last word) must be a flag
        # and cannot have contain an eq sign.
        if nlast.startsWith('-') and not ('=' in nlast):
            # Show all available flag option values.
            if islast_aspace:
                # Check if the flag exists in the following format: '--flag='
                var matches = findAll(acdef, re(pattern, {reMultiLine}))
                if matches.len > 0:
                    # Check if flag exists with option(s).
                    var pattern = nlast & "=(?!\\*).*?(\\||$)"
                    if contains(matches[0], re(pattern)):
                        # Reset needed data.
                        # Modify last used flag.
                        # [https://www.perl.com/article/6/2013/3/28/Find-the-index-of-the-last-element-in-an-array/]
                        foundflags[foundflags.len - 1] = foundflags[foundflags.len - 1] & "="
                        last = nlast & "="
                        lastchar = "="
                        autocompletion = true
            else: # Complete currently started value option.
                # Check if the flag exists in the following format: '--flag='
                var matches = findAll(acdef, re(pattern, {reMultiLine}))
                if matches.len > 0:
                    # Escape special chars: [https://stackoverflow.com/a/576459]
                    # [http://perldoc.perl.org/functions/quotemeta.html]
                    var pattern = nlast & "=" & fn_quotemeta(last) & ".*?(\\||$)"

                    # Check if flag exists with option(s).
                    if contains(matches[0], re(pattern)):
                        # Reset needed data.
                        last = nlast & "=" & last
                        lastchar = fn_lastchar(last)
                        autocompletion = true

    # Parse used flags and place into a hash for quick lookup later on.
    # [https://perlmaven.com/multi-dimensional-hashes]
    for uflag in foundflags:
        # Parse used flag without RegEx.
        var uflag_fkey = uflag
        var uflag_value = ""

        # If flag contains an eq sign.
        # [https://stackoverflow.com/a/87565]
        # [https://perldoc.perl.org/perlvar.html]
        # [https://www.perlmonks.org/?node_id=327021]
        if '=' in uflag_fkey:
            # Get eq sign index.
            var eqsign_index = uflag.find('=')
            uflag_fkey = uflag.substr(0, eqsign_index - 1)
            uflag_value = uflag.substr(eqsign_index + 1, uflag.len)


        # Store flag key and its value in hashes.
        # [https://perlmaven.com/multi-dimensional-hashes]

        if uflag_value != "":
            if not usedflags.hasKey(uflag_fkey):
                usedflags[uflag_fkey] = initTable[string, int]()
                usedflags[uflag_fkey].add(uflag_value, 1)
        else: usedflags_valueless[uflag_fkey] = 1

        # Track amount of times flag was used.
        if not usedflags_counts.hasKey(uflag_fkey):
            usedflags_counts[uflag_fkey] = 1
        else:
            var count = usedflags_counts[uflag_fkey]
            usedflags_counts[uflag_fkey] = count + 1

# Lookup command/subcommand/flag definitions from the acdef to return
#     possible completions list.
proc fn_lookup(): string =
    # Skip logic if last word is quoted or completion variable is off.
    if isquoted or not autocompletion: return ""

    # Flag completion (last word starts with a hyphen):
    if last.startsWith('-'): # If a flag...
        # Lookup flag definitions from acdef.
        var letter = if commandchain != "": commandchain[1] else: '_'
        commandchain = if commandchain != "": commandchain else: "_"
        if db_dict.hasKey(letter) and db_dict[letter].hasKey(commandchain):
            # Continue if rows exist.
            var parsedflags = initTable[string, int]()

            # Get flags list.
            var flag_list = db_dict[letter][commandchain]["flags"][0]

            # Set completion type:
            ac_type = "flag"

            # If no flags exist skip line.
            if flag_list == "--":  return ""

            # Split by unescaped pipe '|' characters:
            # [https://www.perlmonks.org/bare/?node_id=319761]
            # var flags = flag_list.split("(?:\\\\\|)|(?:(?<!\\)\|)")
            var flags = flag_list.split(re"(?<!\\)\|")

            # Parse last flag without RegEx.
            var last_fkey = last
            # my $flag_isbool
            var last_eqsign = ""
            var last_multif = ""
            var last_value = ""

            # If flag contains an eq sign.
            # [https://stackoverflow.com/a/87565]
            # [https://perldoc.perl.org/perlvar.html]
            # [https://www.perlmonks.org/?node_id=327021]
            if '=' in last_fkey:
                # Get eq sign index.
                var eqsign_index = last.find('=')
                last_fkey = last.substr(0, eqsign_index - 1)
                last_value = last.substr(eqsign_index + 1)

                # Check for multi-flag indicator.
                if last_value.startsWith('*'):
                    last_multif = "*"
                    last_value = fn_rm_firstchar(last_value)

                last_eqsign = "="

            # Check whether last value is quoted.
            var last_val_quoted = last_value.find({'"', '\''}) == 0

            # Loop over flags to process.
            var i = 0
            while i < flags.len:
                var flag = flags[i]

                # # Skip flags not starting with same char as last word.
                # [https://stackoverflow.com/a/55455061]
                if not flag.startsWith(last_fkey):
                    i = i + 1
                    continue

                # Breakup flag into its components (flag/value/etc.).
                # [https://stackoverflow.com/q/19968618]

                var flag_fkey = flag
                var flag_isbool = ""
                var flag_eqsign = ""
                var flag_multif = ""
                var flag_value = ""
                var cflag = ""

                # If flag contains an eq sign.
                # [https://stackoverflow.com/a/87565]
                # [https://perldoc.perl.org/perlvar.html]
                # [https://www.perlmonks.org/?node_id=327021]
                if '=' in flag_fkey:
                    var eqsign_index = flag.find('=')
                    flag_fkey = flag.substr(0, eqsign_index - 1)
                    flag_value = flag.substr(eqsign_index + 1)
                    flag_eqsign = "="

                    # Extract boolean indicator.
                    if '?' in flag_fkey:
                        # Remove boolean indicator.
                        flag_isbool = fn_lastchar(flag_fkey)
                        flag_fkey = fn_rm_lastchar(flag_fkey)

                    # Check for multi-flag indicator.
                    if flag_value.startsWith('*'):
                        flag_multif = "*"
                        flag_value = fn_rm_firstchar(flag_value)

                        # Track multi-starred flags.
                        usedflags_multi[flag_fkey] = 1

                    # Create completion item flag.
                    cflag = flag_fkey & "=" & flag_value

                    # If value is a command-flag: --flag=$("<COMMAND-STRING>"),
                    # run command and add returned words to flags array.
                    if flag_value.startsWith("$(") and flag_value.endsWith(')'):
                        fn_execute_command(flag_value, flags, last_fkey)
                        # [https://stackoverflow.com/a/31288153]
                        # Skip flag to not add literal command to completions.
                        i = i + 1
                        continue

                    # Store flag for later checks...
                    parsedflags[flag_fkey & "=" & flag_value] = 1
                else:
                    # Check for boolean indicator.
                    if '?' in flag_fkey:
                        # Remove boolean indicator and reset vars.
                        flag_isbool = fn_lastchar(flag_fkey)
                        flag_fkey = fn_rm_lastchar(flag_fkey)

                    # Create completion item flag.
                    cflag = flag_fkey

                    # Store flag for later checks...
                    parsedflags[flag_fkey] = 1;

                # Unescape flag?
                # flag = fn_unescape(flag)

                # If the last flag/word does not have an eq-sign, skip flags
                # with values as it's pointless to parse them. Basically, if
                # the last word is not in the form "--form= + a character",
                # don't show flags with values (--flag=value).
                if last_eqsign == "" and flag_value != "" and flag_multif == "":
                    i = i + 1
                    continue

                # START: Remove duplicate flag logic. ==========================

                # Dupe value defaults to false.
                var dupe = 0

                # If it's a multi-flag then let it through.
                if usedflags_multi.hasKey(flag_fkey):

                    # # Although a multi-starred flag, check if value has been used or not.
                    # if flag_value != "" and (usedflags.hasKey(flag_fkey) and usedflags[flag_fkey].hasKey(flag_value)):
                    #     dupe = 1

                    # Although a multi-starred flag, check if value has been used or not.
                    if flag_value != "":
                        # Add flag to usedflags root level.
                        if not usedflags.hasKey(flag_fkey):
                            usedflags[flag_fkey] = initTable[string, int]()
                        if usedflags[flag_fkey].hasKey(flag_value):
                            dupe = 1

                elif flag_eqsign == "":

                    # Valueless --flag (no-value) dupe check.
                    if usedflags_valueless.hasKey(flag_fkey): dupe = 1

                else: # --flag=<value> (with value) dupe check.

                    # Count substring occurrences: [https://stackoverflow.com/a/9538604]
                    # Dereference before use: [https://stackoverflow.com/a/37438262]
                    var flag_values = usedflags.hasKey(flag_fkey)

                    # If usedflags contains <flag:value> at root level...
                    if flag_values:
                        # If no values exists...
                        if flag_value == "": dupe = 1 # subl -n 2, subl -n 23

                        # Else check that value exists...
                        # elif usedflags.hasKey(flag_fkey) and usedflags[flag_fkey].hasKey(flag_value):

                        else:
                            # Add flag to usedflags root level.
                            if not usedflags.hasKey(flag_fkey):
                                usedflags[flag_fkey] = initTable[string, int]()
                            if usedflags[flag_fkey].hasKey(flag_value):
                                dupe = 1 # subl -n 23 -n

                    # If no root level entry...
                    else:
                        # if last == flag_fkey:
                        #   dupe = 0 # subl --type, subl --type= --type
                        # else:

                        # It last word/flag key match and flag value is used.
                        if last != flag_fkey and usedflags_valueless.hasKey(flag_fkey):
                            # Add flag to usedflags root level.
                            if not usedflags.hasKey(flag_fkey):
                                usedflags[flag_fkey] = initTable[string, int]()
                            if not usedflags[flag_fkey].hasKey(flag_value):
                                dupe = 1 # subl --type=, subl --type= --

                # If flag is a dupe skip it.
                if dupe == 1:
                    i = i + 1
                    continue

                # Note: Don't list single letter flags. Listing them along
                # with double hyphen flags is awkward. Therefore, only list
                # then when completing or showing its value(s).
                if flag_fkey.len == 2 and flag_value == "":
                    i = i + 1
                    continue

                # END: Remove duplicate flag logic. ============================

                # If last word is in the form → "--flag=" then we need to
                # remove the last word from the flag to only return its
                # options/values.
                if last_eqsign != "":
                    # Flag value has to start with last flag value.
                    if not flag_value.startsWith(last_value) or flag_value == "":
                        i = i + 1
                        continue
                    # Reset completions array value.
                    cflag = flag_value

                # Note: This is more of a hack check. Values with
                # special characters will sometime by-pass the
                # previous checks so do one file check. If the
                # flag is in the following form:
                # --flags="value-string" then we do not add is to
                # the completions list. Final option/value check.
                # my $__isquoted = ($flag_eqsign and $flag_val_quoted);
                # if (!$__isquoted and $flag ne $last) {

                completions.add(cflag)

                # inc(i) # Increment counter
                i = i + 1 # Increment counter

            # Note: Account for quoted strings. If last value is quoted, then
            # add closing quote.
            if last_val_quoted:
                # Get starting quote (i.e. " or ').
                var quote = $(last_value[0])

                # Close string with matching quote if not already.
                if fn_lastchar(last_value) != quote:
                    last_value &= quote

                # Add quoted indicator to type string to later escape
                # for double quoted strings.
                ac_type = "flag;quoted"
                if quote == "\"":
                    ac_type &= ";noescape"

                # If the value is empty return.
                if last_value.len == 2:
                    completions.add("$quote$quote")
                    return ""

            # If no completions exists then simply add last item to Bash
            # completion can add append a space to it.
            if completions.len == 0:
                var key = last_fkey & (if last_value == "": "" else: "=" & last_value)
                var item = if last_value == "": last else: last_value
                # [https://www.perlmonks.org/?node_id=1003939]
                if parsedflags.hasKey(key): completions.add(item)
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
                    # Remove values of same length as current value.
                    # [https://stackoverflow.com/a/15952649]
                    completions = filter(completions, proc (x: string): bool =
                        x.len != last_val_length
                    )
    else: # Command completion:

        # Set completion type:
        ac_type = "command"

        # If command chain and used flags exits, don't complete.
        if usedflags.len > 0 and commandchain != "":
            # Reset commandchain.
            commandchain = if last == "": "" else: last

        # var pattern = "^" & fn_quotemeta(commandchain)
        var pattern = "^" & commandchain

        # When there is no command chain get the first level commands.
        if commandchain == "" and last == "":
            # [https://github.com/nim-lang/Nim/issues/943]
            if db_levels.hasKey(1): completions = toSeq(db_levels[1].keys)
        else:
            var letter = if commandchain != "": commandchain[1] else: '_'
            # [https://stackoverflow.com/a/33102092]
            var rows = toSeq(db_dict[letter].keys)
            var lastchar_notspace = lastchar != " "

            # If no rows...
            if rows.len == 0: return ""

            var usedcommands = initTable[string, int]()
            var commands = (fn_rm_firstchar(commandchain)).split(re"(?<!\\)\.")
            var level = commands.len - 1
            # Increment level if completing a new command level.
            if lastchar == " ": level = level + 1

            # Get commandchains for specific letter outside of loop.
            var h = db_dict[letter]

            # Split rows by lines: [https://stackoverflow.com/a/11746174]
            for rw in rows:
                var row = rw # Copy for later use.

                # Only continue if commands key exists.
                if not h[row].hasKey("commands"): continue

                var cmds = h[row]["commands"]
                # Get the needed level.
                row = if level < cmds.len: cmds[level] else: ""

                # Add last command it not yet already added.
                if row == "" or usedcommands.hasKey(row): continue
                # If the character before the caret is not a
                # space then we assume we are completing a
                # command.
                if lastchar_notspace:
                    # Since we are completing a command we only
                    # want words that start with the current
                    # command we are trying to complete.
                    if row.startsWith(last): completions.add(row)
                    # if row.find(last) == 0: completions.add(row)
                else:
                    # If we are not completing a command then
                    # we return all possible word completions.
                    completions.add(row)

                # Store command in hash.
                usedcommands[row] = 1

        # Note: If there is only one command in the command completions
        # array, check whether the command is already in the commandchain.
        # If so, empty completions array as it has already been used.
        if nextchar != "" and completions.len == 1:
            var pattern = "." & completions[0] & "(\\.|$)"
            if contains(commandchain, re(pattern)): completions.setLen(0)

        # If no completions exist run default command if it exists.
        if completions.len == 0:
            # Copy commandchain string.
            var copy_commandchain = commandchain
            # Keyword to look for.
            var keyword = "default"

            # Loop over command chains to build individual chain levels.
            while copy_commandchain != "":
                # Get command-string, parse it, then run it...
                var command_str = if db_fallbacks.hasKey(copy_commandchain): db_fallbacks[copy_commandchain] else: ""
                if command_str != "":
                    # Store matched RegExp pattern value.
                    var value = command_str
                    # If match exists...
                    # Check if it is a command-string.
                    var pattern = "^\\$\\((.*?)\\)$"
                    var matches = findAll(value, re(pattern, {reMultiLine}))
                    if matches.len > 0:
                        # Get the command-flag.
                        # Parse user provided command-flag command.
                        var empty_seq = @[""]
                        fn_execute_command(matches[0], empty_seq)
                    # Else it is a static non command-string value.
                    else:
                        if last != "":
                            # When last word is present only
                            # add words that start with last
                            # word.

                            # Since we are completing a command we only
                            # want words that start with the current
                            # command we are trying to complete.
                            if value.startsWith(last):
                            # if ($value =~ /$elast_ptn/) {
                                # Finally, add to flags array.
                                completions.add(value)
                        else:
                            # Finally, add to flags array.
                            completions.add(value)

                    # Stop loop once a command-string is found and ran.
                    break

                # Remove last command chain from overall command chain.
                copy_commandchain = copy_commandchain.replace(re("\\.((?:\\\\\\.)|[^\\.])+$")) # ((?:\\\.)|[^\.]*?)*$

            # # Note: 'always' keyword has quirks so comment out for now.
            # # Note: When running the 'always' fallback should the current command
            # # chain's fallback be looked and run or should the command chain also
            # # be broken up into levels and run the first available fallback always
            # # command-string?
            # my @chains = ($commandchain);
            # __fallback_cmd_string('always', \@chains);

# Parses CLI input. Returns input similar to that of process.argv.slice(2).
#     Adapted from argsplit module.
#
# @param {string} 1) - The string to parse.
# @return {undefined} - Nothing is returned.
proc fn_parser() =
    # Vars.
    var argument = ""
    var qchar = ""
    var input = input # Copy string since it ill be destroyed during loop.
    # Loop character variables (current, previous characters).
    var c, p = ""

    # Input must not be empty.
    if input == "": return

    # Given the following input: '-n5 -abc "val"', the input will be turned
    #     into '-n 5 -a -b -c "val"'.
    #
    # @param {string} 1) - The string to spread.
    # @return {string}   - The remaining argument.
    proc fn_spread(argument: var string): string =
        # Must pass following checks:
        # - Start with a hyphen.
        # - String must be >= 3 chars in length.
        # - Must only start with a single hyphen.
        if argument.len >= 3 and argument[1] != '-':
            argument.removePrefix('-') # Remove hyphen from argument.
            var lchar = fn_lastchar(argument) # Get last letter.

            # If the last character is a number then everything after the
            # first letter character (the flag) is its value.
            if lchar in "0123456789":
                # Get the single letter argument.
                var argletter = argument[0]
                # Remove first char (letter) from argument.
                argument.removePrefix(argletter)

                # Add letter argument to args array.
                args.add(fmt"-{argletter}")

            # Else, all other characters after are individual flags.
            else:
                # Add each other characters as single hyphen flags.
                var chars = fn_split_by_chars(argument)
                var i = 0
                var hyphenref = false
                for chr in chars:
                    # Handle: 'sudo wget -qO- https://foo.sh':
                    # Hitting a hyphen breaks loop. All characters at hyphen
                    # and beyond are now the value of the last argument.
                    if chr == '-':
                        hyphenref = true
                        break
                    args.add(fmt"-{chr}")
                    i = i + 1

                # Reset value to final argument.
                argument = if not hyphenref: fmt"-{lchar}" else: argument.substr(i)

        return argument

    while input != "":
        # [https://www.perlmonks.org/?node_id=873068]
        # [https://www.perlmonks.org/?node_id=833345]
        # [https://www.perlmonks.org/?node_id=223573]
        # [https://www.tek-tips.com/viewthread.cfm?qid=1056438]
        # [https://www.oreilly.com/library/view/perl-cookbook/1565922433/ch01s06.html]
        # [https://stackoverflow.com/questions/1083269/is-perls-unpack-ever-faster-than-substr]
        # Note: Of all methods tried to parse a string of text char-by-char
        # this method seems the fastest. Here's how it works. Using a while
        # loop we chip away at the first character from the string. Therefore,
        # the loop will end once the string is empty (no more characters).
        # The way substr is used here is basically a reverse chop and is
        # surprisingly pretty fast. Also, this method does not require the
        # need of using the length method to loop. Moreover, we need also need
        # the previous char. To get it, instead of making another call to
        # substr we use the chop method which is super fast. Once the last
        # character is chopped we just append it right back. This combination
        # is the fastest of all methods tried.

        # Get needed characters.
        c = fn_firstchar(input) # 'Chop' first char from string.
        input = fn_rm_firstchar(input) # Remove the first char from string.
        p = fn_lastchar(argument) # Get last char from argument.

        # qchar is set, grab all chars until an unescaped qchar is hit.
        if qchar != "":
            # Capture character.
            argument &= c

            if c == qchar and p != "\\":
                # Note: Check that argument is spaced out. For example, this
                # is invalid: '$ nodecliac format --indent="t:1"--sa'
                # ----------------------------------------------^. Should be:
                #          '$ nodecliac format --indent="t:1" --sa'
                # -------------------------------------------^Whitespace char.
                # If argument is not spaced out or at the end of the input
                # don not add it to the array. Just skip to next iteration.
                if input != "" and input.startsWith(' '): continue

                # Store argument and reset vars.
                let value = if not argument.startsWith('-'): argument else: fn_spread(argument)
                args.add(value)
                # Clear/reset variables.
                argument = ""
                qchar = ""

        else:
            # Check if current character is a quote character.
            if c in ["\"", "'"] and p != "\\":
                # Set qchar as the opening quote character.
                qchar = c
                # Capture character.
                argument &= c

            # For non quote characters add all except non-escaped spaces.
            elif c in [" ", "\t"] and p != "\\":
                # If argument variable is not populated don't add to array.
                if argument == "": continue

                # Store argument and reset vars.
                let value = if not argument.startsWith('-'): argument else: fn_spread(argument)
                args.add(value)
                # Clear/reset variables.
                argument = ""
                qchar = ""
            else:
                # Capture character.
                argument &= c

    # # Get last argument.
    if argument != "":
        # Store argument and reset vars.
        let value = if not argument.startsWith('-'): argument else: fn_spread(argument)
        args.add(value)

    # Get/store last character of input.
    lastchar = if not (c != " " and p != "\\"): c else: ""

# Send all possible completions to bash.
proc fn_printer() =
    # Build and contains all completions in a string.
    var lines = ac_type & ":" & last
    # ^ The first line will contain meta information about the completion.

    # Check whether completing a command.
    var iscommand = ac_type == "command"
    # Add new line if completing a command.
    if iscommand: lines &= "\n"

    # Determine what list delimiter to use.
    var sep = if iscommand: " " else: "\n"
    # Check completing flags.
    var isflag_type = ac_type.startsWith('f')

    # [https://perlmaven.com/transforming-a-perl-array-using-map]
    # [https://stackoverflow.com/a/2725641]
    # Loop over completions and append to list.
    completions = map(completions, proc (x: string): string =
        # Add trailing space to all completions except to flag
        # completions that end with a trailing eq sign, commands
        # that have trailing characters (commands that are being
        # completed in the middle), and flag string completions
        # (i.e. --flag="some-word...).
        let final_space = if isflag_type and not x.endsWith('=') and x.find({'"', '\''}) != 0 and nextchar == "": " " else: ""

        # Final returned item.
        sep & x & final_space
    )

    # Return data.
    echo lines & completions.join("")

proc fn_makedb() =
    # To list all commandchains/flags without a commandchain.
    if commandchain == "":
        # Note: Although not DRY, per say, dedicating specific logic routes
        # speeds up auto-completion tremendously.

        # For first level commands only...
        if last == "":
            for line in acdef.split("\n"):
                # First character must be a period or a space.
                if not line.startsWith('.'): continue

                # Get command/flags/fallbacks from each line.
                var space_index = line.find(' ')
                var chain = line.substr(1, space_index - 1)

                # Parse chain.
                var dot_index = chain.find('.')
                var command = chain.substr(0, if dot_index != -1: dot_index - 1 else: space_index)

                # Add first level to table it not already added.
                if not db_levels.hasKey(1): db_levels[1] = initTable[string, int]()
                db_levels[1][command] = 1 # Add command to table.

        # For first level flags...
        else:
            # Get main command flags.
            var matches = findAll(acdef, re("^ ([^\n]+)", {reMultiLine}))
            if matches.len > 0:
                db_dict['_'] = initTable[string, Table[string, seq[string]]]()
                db_dict['_']["_"] = initTable[string, seq[string]]()
                # Left trim match as findAll has odd group matching behavior:
                # [Bug: https://github.com/nim-lang/Nim/issues/12267]
                db_dict['_']["_"].add("flags", @[matches[0].strip(trailing = false)])

    # General auto-completion. Parse entire .acdef file contents.
    else:
        # Get the first letter of commandchain to better filter ACDEF data.
        # var fletter = fn_firstchar(commandchain)

        # Extract and place command chains and fallbacks into their own arrays.
        # [https://www.perlmonks.org/?node_id=745018], [https://perlmaven.com/for-loop-in-perl]
        for lne in acdef.split("\n"):
            var line = lne # Create useable copy of line.

            # First filter: First character must be a period or a space. Or
            # if the command line does not start with the first letter of the
            # command chain then we skip all line parsing logic.
            # [https://stackoverflow.com/q/30403331]
            if not line.startsWith(commandchain): continue

            # Get command/flags/fallbacks from each line.
            # my $space_index = index($line, ' ');
            # my $chain = substr($line, 1, $space_index - 1);
            # my $remainder = substr($line, $space_index + 1);
            #
            # [https://stackoverflow.com/a/33192235]
            # **Note: From this point forward to not copy the line string,
            # the remainder (flags part of the line) is now the line itself.
            # my $remainder = $line;
            # [https://stackoverflow.com/a/92935]
            var chain = line.substr(0, line.find(' ') - 1)
            # Remove chain from line to leave flags string.
            line.removePrefix(chain & " ")

            # Second filter: If retrieving the next possible levels for the
            # command chain, the lastchar must be an empty space and and
            # the commandchain does not equal the chain of the line then
            # we skip the line.
            if lastchar == " " and not (chain & ".").startsWith(commandchain & "."): continue

            # Parse chain.
            var commands = (fn_rm_firstchar(chain)).split(re"(?<!\\)\.")
            # var commands = chain.split(re"(?<!\\)\.")

            # Cleanup remainder (flag/command-string).
            if ord(line[0]) == 45:
                # Create dict entry letter/command chain.
                var fchar = chain[1]
                # var cchain = fn_rm_firstchar(chain)
                var cchain = chain

                # Add letter entry to table if it does not exist.
                if not db_dict.hasKey(fchar):
                    db_dict[fchar] = initTable[string, Table[string, seq[string]]]()

                # Add entry to table not that entry exists.
                db_dict[fchar][cchain] = initTable[string, seq[string]]()
                db_dict[fchar][cchain].add("commands", commands)
                db_dict[fchar][cchain].add("flags", @[line])

            else:
                # Store fallback.
                if not db_fallbacks.hasKey(chain): db_fallbacks[chain] = line.substr(8)

# (cli_input*) → parser → extractor → lookup → printer
# *Supply CLI input from start to caret index.
fn_parser()
fn_extractor()
# fn_debug()
fn_makedb()
discard fn_lookup()
fn_printer()
