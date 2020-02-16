from tables import Table, `[]=`, `$`, pairs

from ../helpers/tree_add import add
from ../helpers/types import State, node
import ../helpers/[error, validate, forward, rollback]
from ../helpers/patterns import
    c_nl, c_letters, c_setting_chars, c_spaces, c_quotes, c_setting_value

# ------------------------------------------------------------ Parsing Breakdown
# $variable = "value"
#          | |       ^-EOL-Whitespace-Boundary 3.
#          ^-^-Whitespace-Boundary 1/2.
# ^-Sigil.
#  ^-Name.
#           ^-Assignment.
#             ^-Value.
# ------------------------------------------------------------------------------
#
# @param  {object} S - State object.
# @return - Nothing is returned.
proc p_variable*(S: State) =
    let text = S.text
    var qchar: char
    var state = "sigil"
    var N = node(S, "VARIABLE")

    var `char`: char
    while S.i < S.l:
        `char` = text[S.i]

        if `char` in c_nl:
            rollback(S)
            N.`end` = S.i
            break # Stop at nl char.

        case (state):
            of "sigil":
                N.sigil.start = S.i
                N.sigil.`end` = S.i
                state = "name"

            of "name":
                if N.name.value == "":
                    if `char` notin c_letters: error(S, currentSourcePath)

                    N.name.start = S.i
                    N.name.`end` = S.i
                    N.name.value = $`char`
                else:
                    if `char` in c_setting_chars:
                        N.name.`end` = S.i
                        N.name.value &= $`char`
                    elif `char` in c_spaces:
                        state = "name-wsb"
                        forward(S)
                        continue
                    elif `char` == '=':
                        state = "assignment"
                        rollback(S)
                    else: error(S, currentSourcePath)

            of "name-wsb":
                if `char` notin c_spaces:
                    if `char` == '=':
                        state = "assignment"
                        rollback(S)
                    else: error(S, currentSourcePath)

            of "assignment":
                N.assignment.start = S.i
                N.assignment.`end` = S.i
                N.assignment.value = $`char`
                state = "value-wsb"

            of "value-wsb":
                if `char` notin c_spaces:
                    state = "value"
                    rollback(S)

            of "value":
                if N.value.value == "":
                    if `char` notin c_setting_value: error(S, currentSourcePath)

                    if `char` in c_quotes: qchar = `char`
                    N.value.start = S.i
                    N.value.`end` = S.i
                    N.value.value = $`char`
                else:
                    if qchar != '\0':
                        let pchar = text[S.i - 1]

                        if `char` == qchar and pchar != '\\': state = "eol-wsb"
                        N.value.`end` = S.i
                        N.value.value &= $`char`
                    else:
                        if `char` in c_spaces:
                            state = "eol-wsb"
                            rollback(S)
                        else:
                            N.value.`end` = S.i
                            N.value.value &= $`char`

            of "eol-wsb":
                if `char` notin c_spaces: error(S, currentSourcePath)

            else: discard

        forward(S)

    discard validate(S, N)
    add(S, N)

    var value = if N.value.value != "": N.value.value else: ""
    value = value[1 .. ^2]

    S.tables.variables[N.name.value] = value # Store var/val.

