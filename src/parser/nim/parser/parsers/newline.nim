from "../helpers/types" import State, node
from "../helpers/tree_add" import add

# ------------------------------------------------------------ Parsing Breakdown
# \n
# ^-Newline character.
# ------------------------------------------------------------------------------

# @param  {object} S - State object.
# @return Nothing is returned.
proc p_newline*(S: var State) =
    var N = node(S, "NEWLINE")

    N.start = S.i
    N.end = S.i

    S.line = S.line + 1
    S.column = 0
    S.sol_char = ""

    add(S, N)
