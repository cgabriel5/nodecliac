import std/tables

import ../helpers/[tree_add, types, charsets]
import ../helpers/[error, validate, forward, rollback, brace_checks]

# ------------------------------------------------------------ Parsing Breakdown
# - value
#  |     ^-EOL-Whitespace-Boundary 2
#  ^-Whitespace-Boundary 1
# ^-Bullet
#  ^-Value
# ------------------------------------------------------------------------------
#
# @param  {object} S - State object.
# @return {undefined} - Nothing is returned.
proc p_option*(S: State): Node =
    let text = S.text
    var state = "bullet"
    var `type` = "escaped"
    var N = node(nkOption, S)
    var qchar: char
    var comment = false
    var braces: seq[int] = @[]

    # Error if flag scope doesn't exist.
    bracechecks(S, check = "pre-existing-fs")

    let l = S.l; var c, p: char
    while S.i < l:
        p = c
        c = text[S.i]

        if c in C_NL:
            rollback(S)
            N.stop = S.i
            break # Stop at nl char.

        if c == '#' and p != '\\' and (state != "value" or comment):
            rollback(S)
            N.stop = S.i
            break

        case (state):
            of "bullet":
                N.bullet.start = S.i
                N.bullet.stop = S.i
                N.bullet.value = $c
                state = "spacer"

            of "spacer":
                if c notin C_SPACES: error(S, currentSourcePath)
                state = "wsb-prevalue"

            of "wsb-prevalue":
                if c notin C_SPACES:
                    rollback(S)
                    state = "value"

            of "value":
                if N.value.value == "":
                    # Determine value type.
                    if c == '$': `type` = "command-flag"
                    elif c == '(':
                        `type` = "list"
                        braces.add(S.i)
                    elif c in C_QUOTES:
                        `type` = "quoted"
                        qchar = c

                    N.value.start = S.i
                    N.value.stop = S.i
                    N.value.value = $c
                else:
                    case `type`:
                        of "escaped":
                            if c in C_SPACES and p != '\\':
                                state = "eol-wsb"
                                forward(S)
                                continue
                        of "quoted":
                            if c == qchar and p != '\\':
                                state = "eol-wsb"
                            elif c == '#' and qchar == '\0':
                                comment = true
                                rollback(S)
                        else: # list|command-flag
                            # The following character after the initial
                            # '$' must be a '('. If it does not follow,
                            # error.
                            #   --help=$"cat ~/files.text"
                            #   --------^ Missing '(' after '$'.
                            if `type` == "command-flag":
                                if N.value.value.len == 1 and c != '(':
                                    error(S, currentSourcePath)

                            # The following logic, is precursor validation
                            # logic that ensures braces are balanced and
                            # detects inline comment.
                            if p != '\\':
                                if c == '(' and qchar == '\0':
                                    braces.add(S.i)
                                elif c == ')' and qchar == '\0':
                                    # If braces len is negative, opening
                                    # braces were never introduced so
                                    # current closing brace is invalid.
                                    if braces.len == 0: error(S, currentSourcePath)
                                    discard braces.pop()
                                    if braces.len == 0:
                                        state = "eol-wsb"

                                if c in C_QUOTES:
                                    if qchar == '\0':
                                        qchar = c
                                    elif qchar == c:
                                        qchar = '\0'

                                if c == '#' and qchar == '\0':
                                    if braces.len == 0:
                                        comment = true
                                        rollback(S)
                                    else:
                                        S.column = braces.pop() - S.tables.linestarts[S.line]
                                        inc(S.column) # Add 1 to account for 0 base indexing.
                                        error(S, currentSourcePath)

                    N.value.stop = S.i
                    N.value.value &= $c

            of "eol-wsb":
                if c notin C_SPACES: error(S, currentSourcePath)

            else: discard

        forward(S)

    discard validate(S, N)
    add(S, N)
