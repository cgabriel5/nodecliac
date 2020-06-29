from algorithm import sort
from sets import contains, toHashSet
from strutils import join, parseInt, isEmptyOrWhitespace
from tables import `[]=`, `[]`, OrderedTableRef, sort, pairs

import error
from types import State
from charsets import C_QUOTES, C_SPACES, C_CTX_ALL, C_CTX_MUT,
    C_CTX_FLG, C_CTX_CON, C_LETTERS, C_CTX_CAT, C_CTX_OPS

# Validate the provided context string.
#
# @param  {object} S -State object.
# @param  {string} value - The context string.
# @param  {object} vindices - The variable object indices.
# @param  {number} resumepoint - The index loop resume point.
# @return {string} - The cleaned context string.
proc vcontext*(S: State, value: string = "",
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

    # Ignore starting '"' and ending '"' when looping.
    let l = value.high
    while i < l:
        let `char` = value[i]
        if `char` in C_SPACES: inc(i); argument &= `char`; continue
        if `char` notin C_CTX_ALL:
            S.column = tindex(i)
            error(S, currentSourcePath)
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
    # @param  {string} type - The verification type.
    # @param  {number} i - The string's index.
    # @return {string} - Error, else return value if valid.
    proc verify(value, `type`: string, i: int): string =
        let l = value.len
        case (`type`):
            of "marg":
                if value[0] == '-':
                    S.column = tindex(i)
                    error(S, currentSourcePath)
            of "carg":
                    if value[0] == '!':
                        if l < 2:
                            S.column = tindex(i)
                            error(S, currentSourcePath)
                        if value[1] notin C_LETTERS:
                            S.column = tindex(i + 1)
                            error(S, currentSourcePath)
                    else:
                        if l < 1:
                            S.column = tindex(i)
                            error(S, currentSourcePath)
                        if value[0] notin C_LETTERS:
                            S.column = tindex(i + 1)
                            error(S, currentSourcePath)
            of "ccond":
                if value[0] == '#':
                    # Must be at least 5 chars in length.
                    if l < 5:
                        S.column = tindex(i)
                        error(S, currentSourcePath)
                    if value[1] notin C_CTX_CAT:
                        S.column = tindex(i + 1)
                        error(S, currentSourcePath)
                    if value[2 .. 3] notin C_CTX_OPS:
                        S.column = tindex(i + 2)
                        error(S, currentSourcePath)
                    let nval = value[4 .. ^1]
                    try:
                        # Characters at these indices must be
                        # numbers if not, error.
                        discard parseInt(nval)
                    except:
                        S.column = tindex(i + 4)
                        error(S, currentSourcePath)
                    # Error if number starts with 0 and is
                    # more than 2 numbers.
                    if value[4] == '0' and nval.len != 1:
                        S.column = tindex(i + 4)
                        error(S, currentSourcePath)
                else:
                    if value[0] == '!':
                        if l < 2:
                            S.column = tindex(i)
                            error(S, currentSourcePath)
                        if value[1] notin C_LETTERS:
                            S.column = tindex(i + 1)
                            error(S, currentSourcePath)
                    else:
                        if l < 1:
                            S.column = tindex(i)
                            error(S, currentSourcePath)
                        if value[0] notin C_LETTERS:
                            S.column = tindex(i + 1)
                            error(S, currentSourcePath)
            else: discard
        return value

    var resume_index = 1 # Account for initial skipped quote.
    var values: seq[string] = @[]
    for c, arg in args: # Validate parsed arguments.
        var i = 0
        let l = arg.len
        var fchar = '\0'

        # Mutual exclusive variables.
        var marg = ""
        var margs: seq[string] = @[]
        var mopen_br_index = 0
        var mclose = false
        var del_pipe: seq[int] = @[]
        var mindices: seq[int] = @[]

        # Conditional variables.
        var hasconds = false
        var del_cfcomma: seq[int] = @[]
        var cflags: seq[string] = @[]
        var cfindices: seq[int] = @[]
        var carg = ""
        #
        var del_cncomma: seq[int] = @[]
        var cconds: seq[string] = @[]
        var ccindices: seq[int] = @[]
        var ccond = ""

        while i < l:
            let `char` = arg[i]
            if `char` in C_SPACES:
                inc(i); inc(resume_index); continue

            if fchar == '\0':
                fchar = `char`
                if fchar == '{':
                    mopen_br_index = resume_index
                    inc(i); inc(resume_index); continue

            if fchar == '{': # Mutual exclusivity.
                if `char` notin C_CTX_MUT:
                    S.column = tindex(resume_index)
                    error(S, currentSourcePath)

                # Braces were closed but nws char found.
                if mclose and `char` notin C_SPACES:
                    S.column = tindex(resume_index)
                    error(S, currentSourcePath)

                if `char` == '}':
                    mclose = true
                    inc(i); inc(resume_index); continue

                if `char` == '|':
                    if isEmptyOrWhitespace(marg):
                        S.column = tindex(resume_index)
                        error(S, currentSourcePath, 14)
                    del_pipe.add(resume_index)
                    margs.add(verify(marg, "marg", mindices[^1]))
                    marg = ""
                    inc(i); inc(resume_index); continue

                if marg == "": mindices.add(resume_index)
                marg &= `char`

            else: # Conditionals.
                if hasconds == false:
                    if `char` notin C_CTX_FLG:
                        S.column = tindex(resume_index)
                        error(S, currentSourcePath)

                    if `char` == ',':
                        if isEmptyOrWhitespace(carg):
                            S.column = tindex(resume_index)
                            error(S, currentSourcePath)
                        del_cfcomma.add(resume_index)
                        cflags.add(verify(carg, "carg", cfindices[^1]))
                        carg = ""
                        inc(i); inc(resume_index); continue
                    elif `char` == ':':
                        hasconds = true
                        if carg.len != 0 and cflags.len == 0:
                            cflags.add(verify(carg, "carg", cfindices[^1]))
                            carg = ""
                        if cflags.len == 0:
                            S.column = tindex(resume_index)
                            error(S, currentSourcePath) # No flags.
                        inc(i); inc(resume_index); continue

                    if carg == "": cfindices.add(resume_index)
                    carg &= `char`

                else:
                    if `char` notin C_CTX_CON:
                        S.column = tindex(resume_index)
                        error(S, currentSourcePath)

                    # If it's not the first character, error.
                    if `char` in {'!', '#'} and ccond != "":
                        S.column = tindex(resume_index)
                        error(S, currentSourcePath)

                    elif `char` == ',':
                        if isEmptyOrWhitespace(ccond):
                            S.column = tindex(resume_index)
                            error(S, currentSourcePath, 14)
                        del_cncomma.add(resume_index)
                        cconds.add(verify(ccond, "ccond", ccindices[^1]))
                        ccond = ""
                        inc(i); inc(resume_index); continue

                    if ccond == "": ccindices.add(resume_index)
                    ccond &= `char`

            inc(i); inc(resume_index)
        # Add 1 to account for ';' delimiter.
        inc(i); inc(resume_index)

        if fchar == '{':
            # Check that braces were closed.
            if mclose == false:
                S.column = tindex(mopen_br_index)
                error(S, currentSourcePath, 17)

            # Check if mutual exclusive braces are empty.
            if marg == "":
                if margs.len == 0:
                    S.column = tindex(mopen_br_index)
                    error(S, currentSourcePath)
            else: margs.add(verify(marg, "marg", mindices[^1]))

            # Error if a trailing '|' delimiter exists.
            if del_pipe.len >= margs.len:
                # Find first trailing semicolon delimiter.
                let pindex = if del_pipe.len == margs.len: del_pipe[^1]
                    else: del_pipe[margs.high + 1]
                S.column = tindex(pindex)
                error(S, currentSourcePath, 14)

            # Build cleaned value string.
            values.add("{" & margs.join("|") & "}")

        else:
            # Get last argument.
            if carg != "": cflags.add(verify(carg, "carg", cfindices[^1]))
            if ccond != "": cconds.add(verify(ccond, "ccond", ccindices[^1]))

            # Error if a trailing flag ',' delimiter exists.
            if del_cfcomma.len > 0 and del_cfcomma.len >= cflags.len:
                # Find first trailing semicolon delimiter.
                let dindex = if del_cfcomma.len == cflags.len: del_cfcomma[^1]
                    else: del_cfcomma[cflags.high + 1]
                S.column = tindex(dindex)
                error(S, currentSourcePath, 14)

            # Error if a trailing conditions ',' delimiter exists.
            if del_cncomma.len > 0 and del_cncomma.len >= cconds.len:
                # Find first trailing semicolon delimiter.
                let dindex = if del_cncomma.len == cconds.len: del_cncomma[^1]
                    else: del_cncomma[cconds.high + 1]
                S.column = tindex(dindex)
                error(S, currentSourcePath, 14)

            # If flags exist but conditions don't, error.
            if cflags.len > 1 and cconds.len == 0:
                let dindex =
                    if del_semicolon.len > 0: del_semicolon[c] - 1
                    else: value.high - 1 # Else, use val length.
                S.column = tindex(dindex)
                error(S, currentSourcePath, 16)

            # Build cleaned value string.
            if cflags.len > 0:
                var val = cflags.join(",")
                if cconds.len > 0:
                    val &= ":" & cconds.join(",")
                values.add(val)

    result = qchar & values.join(";") & qchar
