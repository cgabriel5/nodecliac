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
    var qchar: char
    var state = Sigil
    var N = node(nkSetting, S)

    let l = S.l; var c, p: char
    while S.i < l:
        p = c
        c = S.text[S.i]

        if c in C_NL:
            rollback(S)
            N.stop = S.i
            break # Stop at nl char.

        if c == C_NUMSIGN and p != C_ESCAPE and state != Value:
            rollback(S)
            N.stop = S.i
            break

        case state:
        of Sigil:
            N.sigil.start = S.i
            N.sigil.stop = S.i
            state = Name

        of Name:
            if N.name.value == "":
                if c notin C_LETTERS: error(S)

                N.name.start = S.i
                N.name.stop = S.i
                N.name.value = $c
            else:
                if c in C_SET_IDENT:
                    N.name.stop = S.i
                    N.name.value &= $c
                elif c in C_SPACES:
                    state = NameWsb
                    forward(S)
                    continue
                elif c == C_EQUALSIGN:
                    state = Assignment
                    rollback(S)
                else: error(S)

        of NameWsb:
            if c notin C_SPACES:
                if c == C_EQUALSIGN:
                    state = Assignment
                    rollback(S)
                else: error(S)

        of Assignment:
            N.assignment.start = S.i
            N.assignment.stop = S.i
            N.assignment.value = $c
            state = ValueWsb

        of ValueWsb:
            if c notin C_SPACES:
                state = Value
                rollback(S)

        of Value:
            if N.value.value == "":
                if c notin C_SET_VALUE: error(S)

                if c in C_QUOTES: qchar = c
                N.value.start = S.i
                N.value.stop = S.i
                N.value.value = $c
            else:
                if qchar != C_NULLB:
                    if c == qchar and p != C_ESCAPE:
                        state = EolWsb
                    N.value.stop = S.i
                    N.value.value &= $c
                else:
                    if c in C_SPACES and p != C_ESCAPE:
                        state = EolWsb
                        rollback(S)
                    else:
                        N.value.stop = S.i
                        N.value.value &= $c

        of EolWsb:
            if c notin C_SPACES: error(S)

        else: discard

        forward(S)

    discard validate(S, N)
    add(S, N)

    # Store test.
    if N.name.value == "test": S.tests.add(N.value.value)
