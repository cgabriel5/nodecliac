from ../helpers/tree_add import add
from ../helpers/types import State, node
import ../helpers/[error, validate, forward, rollback]
from ../helpers/charsets import C_NL, C_LETTERS, C_SPACES, C_QUOTES,
    C_SET_IDENT, C_SET_VALUE

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
proc p_setting*(S: State) =
    let text = S.text
    var qchar: char
    var state = "sigil"
    var N = node(S, "SETTING")

    let l = S.l; var `char`: char
    while S.i < l:
        `char` = text[S.i]

        if `char` in C_NL:
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
                    if `char` notin C_LETTERS: error(S, currentSourcePath)

                    N.name.start = S.i
                    N.name.`end` = S.i
                    N.name.value = $`char`
                else:
                    if `char` in C_SET_IDENT:
                        N.name.`end` = S.i
                        N.name.value &= $`char`
                    elif `char` in C_SPACES:
                        state = "name-wsb"
                        forward(S)
                        continue
                    elif `char` == '=':
                        state = "assignment"
                        rollback(S)
                    else: error(S, currentSourcePath)

            of "name-wsb":
                if `char` notin C_SPACES:
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
                if `char` notin C_SPACES:
                    state = "value"
                    rollback(S)

            of "value":
                if N.value.value == "":
                    if `char` notin C_SET_VALUE: error(S, currentSourcePath)

                    if `char` in C_QUOTES: qchar = `char`
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
                        if `char` in C_SPACES:
                            state = "eol-wsb"
                            rollback(S)
                        else:
                            N.value.`end` = S.i
                            N.value.value &= $`char`

            of "eol-wsb":
                if `char` notin C_SPACES: error(S, currentSourcePath)

            else: discard

        forward(S)

    discard validate(S, N)
    add(S, N)

    # Store test.
    if N.name.value == "test": S.tests.add(N.value.value)
