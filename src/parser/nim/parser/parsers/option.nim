from re import match

from ../helpers/tree_add import add
from ../helpers/types import State, Node, node
from ../helpers/patterns import r_nl, r_space, r_quote
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
    var `end` = false # Flag: true - ends consuming chars.
    var `type` = "escaped"
    var N = node(S, "OPTION")

    # Error if flag scope doesn't exist.
    bracechecks(S, check = "pre-existing-fs")

    let l = S.l; var `char`: string
    while S.i < S.l:
        `char` = $text[S.i]

        if match(`char`, r_nl):
            rollback(S)
            N.`end` = S.i
            break # Stop at nl char.

        case (state):
            of "bullet":
                N.bullet.start = S.i
                N.bullet.`end` = S.i
                N.bullet.value = `char`
                state = "spacer"

            of "spacer":
                if not match(`char`, r_space): error(S, currentSourcePath)
                state = "wsb-prevalue"

            of "wsb-prevalue":
                if not match(`char`, r_space):
                    rollback(S)
                    state = "value"

            of "value":
                let pchar = if S.i - 1 < l: $text[S.i - 1] else: ""

                if N.value.value == "":
                    # Determine value type.
                    if `char` == "$": `type` = "command-flag"
                    elif `char` == "(": `type` = "list"
                    elif match(`char`, r_quote): `type` = "quoted"

                    N.value.start = S.i
                    N.value.`end` = S.i
                    N.value.value = `char`
                else:
                    # If flag is set and chars can still be consumed
                    # then there is a syntax error. For example, string
                    # may be improperly quoted/escaped so error.
                    if `end`: error(S, currentSourcePath)

                    let isescaped = pchar != "\\"
                    if `type` == "escaped":
                        if match(`char`, r_space) and isescaped: `end` = true
                    elif `type` == "quoted":
                        let vfchar = N.value.value[0]
                        if `char` == $vfchar and isescaped: `end` = true
                    N.value.`end` = S.i
                    N.value.value &= `char`

            else: discard

        forward(S)

    discard validate(S, N)
    add(S, N)
