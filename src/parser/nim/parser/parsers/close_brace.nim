import ../helpers/[tree_add, types, charsets]
import ../helpers/[error, forward, rollback, brace_checks]

# ------------------------------------------------------------ Parsing Breakdown
# - value
#  |     ^-EOL-Whitespace-Boundary 2
#  ^-Whitespace-Boundary 1
# ^-Bullet
#   ^-Value
# ------------------------------------------------------------------------------
#
# @param  {object} S - State object.
# @return {undefined} - Nothing is returned.
proc p_closebrace*(S: State) =
    let text = S.text
    var state = "brace"
    var N = node(S, "BRACE")

    let l = S.l; var `char`, pchar: char
    while S.i < l:
        pchar = `char`
        `char` = text[S.i]

        if `char` in C_NL:
            rollback(S)
            N.`end` = S.i
            break # Stop at nl char.

        if `char` == '#' and pchar != '\\':
            rollback(S)
            N.`end` = S.i
            break

        case (state):
            of "brace":
                N.brace.start = S.i
                N.brace.`end` = S.i
                N.brace.value = $`char`
                state = "eol-wsb"

            of "eol-wsb":
                if `char` notin C_SPACES: error(S, currentSourcePath)

            else: discard

        forward(S)

    # Error if cc scope exists (brace not closed).
    bracechecks(S, N, "reset-scope")
    add(S, N)
