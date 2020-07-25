from algorithm import sort
from sequtils import delete
from sets import contains, toHashSet
from strutils import join, strip, parseInt, startsWith, isEmptyOrWhitespace
from tables import `[]=`, `[]`, OrderedTableRef, sort, pairs

import error
from types import State
from charsets import C_QUOTES, C_SPACES, C_LETTERS, C_CTX_CTT, C_CTX_OPS

# Validate the provided context string.
#
# @param  {object} S -State object.
# @param  {string} value - The context string.
# @param  {object} vindices - The variable object indices.
# @param  {number} resumepoint - The index loop resume point.
# @return {string} - The cleaned context string.
proc vtest*(S: State, value: string = "",
    vindices: OrderedTableRef[int, tuple[ind, sl: int]],
    resumepoint: int): string =
    # Return true index by accounting for expanded variables.
    #     If a context string uses variables the string will
    #     be expanded. This will then cause the original and
    #     expanded strings to separate in character indices.
    #     This function takes the expanded character index,
    #     figures out its unexpanded index, and returns it.
    #
    # @param  {number} i - The index.
    # @return {number} - The true index.
    proc tindex(index: int): int =
        vindices.sort(system.cmp)
        var i = index
        var vindex = 0
        var vsublen = 0
        for k, v in vindices.pairs:
            let (ind, sl) = v
            if k <= index and i > k:
                i = i + ind
                vindex = k
                vsublen = sl

        # Final check: If index at this point is found in between
        # a variable start/end position, reset the index to the
        # start of the variable position.
        #
        # Note: Range must be at greater than the variable syntax.
        if vindex + vsublen > 3: # Account for '${}' chars.
            let r = {vindex .. vindex + vsublen + 1}
            if i in r: i = vindex
        result = i + resumepoint

    var argument = ""
    var args: seq[string] = @[]
    let qchar = value[0]
    var i = 1 # Account for '"'.
    var del_semicolon: seq[int] = @[]
    var aindices: seq[int] = @[]
    var findex = 0

    # Ignore starting '"' and ending '"' when looping.
    let l = value.high
    while i < l:
        let `char` = value[i]
        if `char` in C_SPACES: inc(i); argument &= `char`; continue
        else:
            if findex == 0: findex = i
        # Handle escaped characters.
        if `char` == '\\':
            if value[i + 1] != '\0':
                argument &= `char` & $value[i + 1]
                inc(i);inc(i)
                continue
        if `char` == ';': # Track semicolons.
            if isEmptyOrWhitespace(argument):
                S.column = tindex(i)
                error(S, currentSourcePath, 14)
            del_semicolon.add(i)
            args.add(argument)
            argument = ""
            inc(i); continue
        aindices.add(i)
        argument &= `char`
        inc(i)
    # Get last argument.
    if not isEmptyOrWhitespace(argument):
        aindices.add(i)
        args.add(argument)

    # Error if a trailing ';' delimiter exists.
    if del_semicolon.len > 0 and del_semicolon.len >= args.len:
        # Find first trailing semicolon delimiter.
        let dindex = if del_semicolon.len == args.len: del_semicolon[^1]
            else: del_semicolon[args.high + 1]
        S.column = tindex(dindex)
        error(S, currentSourcePath, 14)

    # Verifies that provided context string argument type is valid.
    #     Something to note, the provided index is the index of the
    #     first character of the argument. Therefore, if an error
    #     is generated the amount of additional character indices
    #     is added to the index.
    #
    # @param  {string} value - The string to verify.
    # @param  {number} i - The string's index.
    # @return {string} - Error, else return value if valid.
    proc verify(value: string, i: int): string =
        var v = value
        let l = value.len
        # Inversion: Remove '!' for next checks.
        if v[0] == '!': v = v[1 .. ^1]
        if v[0] == '#':
            # Must be at least 5 chars in length.
            if l < 5:
                S.column = tindex(i)
                error(S, currentSourcePath)
            if v[1] notin C_CTX_CTT:
                S.column = tindex(i + 1)
                error(S, currentSourcePath)
            if v[2 .. 3] notin C_CTX_OPS:
                S.column = tindex(i + 2)
                error(S, currentSourcePath)
            let nval = v[4 .. ^1]
            try:
                # Characters at these indices must be
                # numbers if not, error.
                discard parseInt(nval)
            except:
                S.column = tindex(i + 4)
                error(S, currentSourcePath)
            # Error if number starts with 0 and is
            # more than 2 numbers.
            if v[4] == '0' and nval.len != 1:
                S.column = tindex(i + 4)
                error(S, currentSourcePath)
        else:
            if l < 1:
                S.column = tindex(i)
                error(S, currentSourcePath)
            if v[0] notin C_LETTERS:
                S.column = tindex(i + 1)
                error(S, currentSourcePath)
        return value

    # Check that test string starts with main command.
    if not args[0].strip(trailing=true).startsWith(S.tables.variables["COMMAND"]):
        S.column = tindex(findex)
        error(S, currentSourcePath, 15);

    # Account for initial skipped quote/test string.
    var resume_index = if args.len == 0: 1 else: args[0].len + 1
    var values = @[args[0].strip(trailing=false)] # Store before shifting.
    args.delete(0, 0); # Remove test string.
    # Validate parsed arguments.
    for c, arg in args: # Validate parsed arguments.
        var i = 0
        let l = arg.len
        var fchar = '\0'

        while i < l:
            let `char` = arg[i]
            if `char` in C_SPACES:
                inc(i); inc(resume_index); continue

            if fchar == '\0': fchar = `char`
            inc(i); inc(resume_index)
            if fchar == '#':
                discard verify(arg.strip(trailing=true), resume_index)
                continue

        values.add(arg.strip(trailing=true))

        # Add 1 to account for ';' delimiter.
        inc(i); inc(resume_index)

    result = qchar & values.join(";") & qchar
