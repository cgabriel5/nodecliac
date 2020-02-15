from ../helpers/tree_add import add
from ../helpers/types import State, node

# ------------------------------------------------------------ Parsing Breakdown
# \n
# ^-Newline character.
# ------------------------------------------------------------------------------

# @param  {object} S - State object.
# @return Nothing is returned.
proc p_newline*(S: State) =
    var N = node(S, "NEWLINE")

    N.start = S.i
    N.end = S.i

    S.line = S.line + 1
    S.column = 0
    S.sol_char = ""

    add(S, N)
