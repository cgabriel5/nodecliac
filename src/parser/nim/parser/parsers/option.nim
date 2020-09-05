from tables import `[]`

from ../helpers/tree_add import add
from ../helpers/types import State, Node, node
from ../helpers/charsets import C_NL, C_SPACES, C_QUOTES
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
    var N = node(S, "OPTION")
    var qchar: char
    var comment = false
    var braces: seq[int] = @[]

    # Error if flag scope doesn't exist.
    bracechecks(S, check = "pre-existing-fs")

    let l = S.l; var `char`, pchar: char
    while S.i < l:
        pchar = `char`
        `char` = text[S.i]

        if `char` in C_NL:
            rollback(S)
            N.`end` = S.i
            break # Stop at nl char.

        if `char` == '#' and pchar != '\\' and (state != "value" or comment):
            rollback(S)
            N.`end` = S.i
            break

        case (state):
            of "bullet":
                N.bullet.start = S.i
                N.bullet.`end` = S.i
                N.bullet.value = $`char`
                state = "spacer"

            of "spacer":
                if `char` notin C_SPACES: error(S, currentSourcePath)
                state = "wsb-prevalue"

            of "wsb-prevalue":
                if `char` notin C_SPACES:
                    rollback(S)
                    state = "value"

            of "value":
                if N.value.value == "":
                    # Determine value type.
                    if `char` == '$': `type` = "command-flag"
                    elif `char` == '(':
                        `type` = "list"
                        braces.add(S.i)
                    elif `char` in C_QUOTES:
                        `type` = "quoted"
                        qchar = `char`

                    N.value.start = S.i
                    N.value.`end` = S.i
                    N.value.value = $`char`
                else:
                    case `type`:
                        of "escaped":
                            if `char` in C_SPACES and pchar != '\\':
                                state = "eol-wsb"
                                forward(S)
                                continue
                        of "quoted":
                            if `char` == qchar and pchar != '\\':
                                state = "eol-wsb"
                            elif `char` == '#' and qchar == '\0':
                                comment = true
                                rollback(S)
                        else: # list|command-flag
                            # The following character after the initial
                            # '$' must be a '('. If it does not follow,
                            # error.
                            #   --help=$"cat ~/files.text"
                            #   --------^ Missing '(' after '$'.
                            if `type` == "command-flag":
                                if N.value.value.len == 1 and `char` != '(':
                                    error(S, currentSourcePath)

                            # The following logic, is precursor validation
                            # logic that ensures braces are balanced and
                            # detects inline comment.
                            if pchar != '\\':
                                if `char` == '(' and qchar == '\0':
                                    braces.add(S.i)
                                elif `char` == ')' and qchar == '\0':
                                    # If braces len is negative, opening
                                    # braces were never introduced so
                                    # current closing brace is invalid.
                                    if braces.len == 0: error(S, currentSourcePath)
                                    discard braces.pop()
                                    if braces.len == 0:
                                        state = "eol-wsb"

                                if `char` in C_QUOTES:
                                    if qchar == '\0':
                                        qchar = `char`
                                    elif qchar == `char`:
                                        qchar = '\0'

                                if `char` == '#' and qchar == '\0':
                                    if braces.len == 0:
                                        comment = true
                                        rollback(S)
                                    else:
                                        S.column = braces.pop() - S.tables.linestarts[S.line]
                                        inc(S.column) # Add 1 to account for 0 base indexing.
                                        error(S, currentSourcePath)

                    N.value.`end` = S.i
                    N.value.value &= $`char`

            of "eol-wsb":
                if `char` notin C_SPACES: error(S, currentSourcePath)

            else: discard

        forward(S)

    discard validate(S, N)
    add(S, N)
