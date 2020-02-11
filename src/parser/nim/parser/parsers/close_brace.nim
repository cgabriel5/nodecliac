from re import match
from "../helpers/types" import State, node
import "../helpers/error"
import "../helpers/validate"
import "../helpers/forward"
import "../helpers/rollback"
from "../helpers/tree_add" import add
from "../helpers/patterns" import r_nl, r_space
import "../helpers/brace_checks"

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
proc p_closebrace*(S: var State) =
    let text = S.text
    var state = "brace"
    var N = node(S, "BRACE")

    let i = S.i; let l = S.l; var `char`: char
    while S.i < S.l:
        `char` = text[S.i]

        if match($`char`, r_nl):
            rollback(S)
            N.end = S.i
            break # Stop at nl char.

        case (state):
            of "brace":
                N.brace.start = S.i
                N.brace.end = S.i
                N.brace.value = $`char`
                state = "eol-wsb"

            of "eol-wsb":
                if not match($`char`, r_space): error(S, currentSourcePath)

        forward(S)

    # Error if cc scope exists (brace not closed).
    bracechecks(S, N, "reset-scope")
    add(S, N)
