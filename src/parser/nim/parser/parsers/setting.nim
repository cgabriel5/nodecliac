# from tables import Table, `[]`, `$`, pairs
from re import re, match
from "../helpers/types" import State, node
import "../helpers/error"
import "../helpers/validate"
import "../helpers/forward"
import "../helpers/rollback"
from "../helpers/tree_add" import add
from "../helpers/patterns" import r_nl, r_space, r_letter, r_quote

# ------------------------------------------------------------ Parsing Breakdown
# @setting = true
#         | |    ^-EOL-Whitespace-Boundary 3.
#         ^-^-Whitespace-Boundary 1/2.
# ^-Sigil.
#  ^-Name.
#          ^-Assignment.
#            ^-Value.
# ------------------------------------------------------------------------------
#
# @param  {object} S - State object.
# @return - Nothing is returned.
proc p_setting*(S: var State) =
    let text = S.text
    var qchar = ""
    var state = "sigil"
    var N = node(S, "SETTING")

    let i = S.i; let l = S.l; var `char`: char
    while S.i < S.l:
        `char` = text[S.i]

        if match($`char`, r_nl):
            rollback(S)
            N.end = S.i
            break # Stop at nl char.

        case (state):
            of "sigil":
                N.sigil.start = S.i
                N.sigil.end = S.i
                state = "name"

                # break

            of "name":
                if N.name.value == "":
                    if not match($`char`, r_letter): error(S, currentSourcePath)

                    N.name.start = S.i
                    N.name.end = S.i
                    N.name.value = $`char`
                else:
                    if match($`char`, re"[-_a-zA-Z]"):
                        N.name.end = S.i
                        N.name.value &= $`char`
                    elif match($`char`, r_space):
                        state = "name-wsb"
                        forward(S)
                        continue
                    elif $`char` == "=":
                        state = "assignment"
                        rollback(S)
                    else: error(S, currentSourcePath)

            of "name-wsb":
                if not match($`char`, r_space):
                    if $`char` == "=":
                        state = "assignment"
                        rollback(S)
                    else: error(S, currentSourcePath)

            of "assignment":
                N.assignment.start = S.i
                N.assignment.end = S.i
                N.assignment.value = $`char`
                state = "value-wsb"

            of "value-wsb":
                if not match($`char`, r_space):
                    state = "value"
                    rollback(S)

            of "value":
                if N.value.value == "":
                    if not match($`char`, re("[\"'a-zA-Z0-9]")): error(S, currentSourcePath)

                    if match($`char`, r_quote): qchar = $`char`
                    N.value.start = S.i
                    N.value.end = S.i
                    N.value.value = $`char`
                else:
                    if qchar != "":
                        let pchar = text[S.i - 1]

                        if $`char` == qchar and $pchar != "\\": state = "eol-wsb"
                        N.value.end = S.i
                        N.value.value &= $`char`
                    else:
                        if match($`char`, r_space):
                            state = "eol-wsb"
                            rollback(S)
                        else:
                            N.value.end = S.i
                            N.value.value &= $`char`

            of "eol-wsb":
                if not match($`char`, r_space): error(S, currentSourcePath)

            else: discard

        forward(S)

    discard validate(S, N)
    add(S, N)
