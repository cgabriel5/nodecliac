import ../helpers/[tree_add, types, charsets]
import ../helpers/[error, validate, forward, rollback]

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
    var N = node(nkSetting, S)

    let l = S.l; var c, p: char
    while S.i < l:
        p = c
        c = text[S.i]

        if c in C_NL:
            rollback(S)
            N.`end` = S.i
            break # Stop at nl char.

        if c == '#' and p != '\\' and state != "value":
            rollback(S)
            N.`end` = S.i
            break

        case (state):
            of "sigil":
                N.sigil.start = S.i
                N.sigil.`end` = S.i
                state = "name"

            of "name":
                if N.name.value == "":
                    if c notin C_LETTERS: error(S, currentSourcePath)

                    N.name.start = S.i
                    N.name.`end` = S.i
                    N.name.value = $c
                else:
                    if c in C_SET_IDENT:
                        N.name.`end` = S.i
                        N.name.value &= $c
                    elif c in C_SPACES:
                        state = "name-wsb"
                        forward(S)
                        continue
                    elif c == '=':
                        state = "assignment"
                        rollback(S)
                    else: error(S, currentSourcePath)

            of "name-wsb":
                if c notin C_SPACES:
                    if c == '=':
                        state = "assignment"
                        rollback(S)
                    else: error(S, currentSourcePath)

            of "assignment":
                N.assignment.start = S.i
                N.assignment.`end` = S.i
                N.assignment.value = $c
                state = "value-wsb"

            of "value-wsb":
                if c notin C_SPACES:
                    state = "value"
                    rollback(S)

            of "value":
                if N.value.value == "":
                    if c notin C_SET_VALUE: error(S, currentSourcePath)

                    if c in C_QUOTES: qchar = c
                    N.value.start = S.i
                    N.value.`end` = S.i
                    N.value.value = $c
                else:
                    if qchar != '\0':
                        if c == qchar and p != '\\': state = "eol-wsb"
                        N.value.`end` = S.i
                        N.value.value &= $c
                    else:
                        if c in C_SPACES and p != '\\':
                            state = "eol-wsb"
                            rollback(S)
                        else:
                            N.value.`end` = S.i
                            N.value.value &= $c

            of "eol-wsb":
                if c notin C_SPACES: error(S, currentSourcePath)

            else: discard

        forward(S)

    discard validate(S, N)
    add(S, N)

    # Store test.
    if N.name.value == "test": S.tests.add(N.value.value)
