from ../helpers/tree_add import add
import ../helpers/[forward, rollback]
from ../helpers/types import State, node
from ../helpers/charsets import C_NL

# ------------------------------------------------------------ Parsing Breakdown
# # Comment body.
# ^-Symbol.
#  ^-Comment-Chars (All chars until newline).
# ------------------------------------------------------------------------------
#
# @param  {object} S - State object.
# @return - Nothing is returned.
proc p_comment*(S: State) =
    let text = S.text
    var N = node(S, "COMMENT")
    N.comment.start = S.i

    let l = S.l; var `char`: char
    while S.i < l:
        `char` = text[S.i]

        if `char` in C_NL:
            rollback(S)
            N.`end` = S.i
            break # Stop at nl char.

        N.comment.`end` = S.i
        N.comment.value &= $`char`

        forward(S)

    add(S, N)