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
    var N = node(nkBrace, S)

    let l = S.l; var c, p: char
    while S.i < l:
        p = c
        c = text[S.i]

        if c in C_NL:
            rollback(S)
            N.stop = S.i
            break # Stop at nl char.

        if c == '#' and p != '\\':
            rollback(S)
            N.stop = S.i
            break

        case (state):
            of "brace":
                N.brace.start = S.i
                N.brace.stop = S.i
                N.brace.value = $c
                state = "eol-wsb"

            of "eol-wsb":
                if c notin C_SPACES: error(S, currentSourcePath)

            else: discard

        forward(S)

    # Error if cc scope exists (brace not closed).
    bracechecks(S, N, "reset-scope")
    add(S, N)
