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
    var state = Brace
    var N = node(nkBrace, S)

    let l = S.l; var c, p: char
    while S.i < l:
        p = c
        c = S.text[S.i]

        if c in C_NL:
            rollback(S)
            N.stop = S.i
            break # Stop at nl char.

        if c == C_NUMSIGN and p != C_ESCAPE:
            rollback(S)
            N.stop = S.i
            break

        case (state):
            of Brace:
                N.brace.start = S.i
                N.brace.stop = S.i
                N.brace.value = $c
                state = EolWsb

            of EolWsb:
                if c notin C_SPACES: error(S)

            else: discard

        forward(S)

    # Error if cc scope exists (brace not closed).
    bracechecks(S, N, "reset-scope")
    add(S, N)
