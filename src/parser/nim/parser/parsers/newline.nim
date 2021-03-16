import ../helpers/[tree_add, types]

# ------------------------------------------------------------ Parsing Breakdown
# \n
# ^-Newline character.
# ------------------------------------------------------------------------------

# @param  {object} S - State object.
# @return Nothing is returned.
proc p_newline*(S: State) =
    var N = node(nkNewline, S)

    N.start = S.i
    N.`end` = S.i

    S.line = S.line + 1
    S.column = 0
    S.sol_char = '\0'

    add(S, N)
