import flag
from ../helpers/tree_add import add
from ../helpers/types import State, Node, node
import ../helpers/[error, tracer, forward, rollback, brace_checks]
from ../helpers/charsets import C_NL, C_SPACES,
    C_CMD_IDENT_START, C_CMD_IDENT, C_CMD_VALUE

# ------------------------------------------------------------ Parsing Breakdown
# program.command
# program.command ,
# program.command =
# program.command = [
# program.command = [ ]?
# program.command = --flag
#                | |
#                ^-^-Whitespace-Boundary 1/2
# ^-Command-Chain
#                 ^-Assignment
#                   ^-Opening-Bracket
#                    ^-Whitespace-Boundary 3
#                     ^-Optional-Closing-Bracket?
#                      ^-EOL-Whitespace-Boundary 4
# ------------------------------------------------------------------------------
#
# @param  {object} S - State object.
# @return {object} - Node object.
proc p_command*(S: State) =
    let text = S.text
    var state = "command"
    var N = node(S, "COMMAND")

    # Error if cc scope exists (brace not closed).
    bracechecks(S, check = "pre-existing-cs")

    let l = S.l; var `char`: char
    while S.i < l:
        `char` = text[S.i]

        if `char` in C_NL:
            rollback(S)
            N.`end` = S.i
            break # Stop at nl char.

        case (state):
            of "command":
                if N.command.value == "":
                    if `char` notin C_CMD_IDENT_START : error(S, currentSourcePath)

                    N.command.start = S.i
                    N.command.`end` = S.i
                    N.command.value &= $`char`
                else:
                    if `char` in C_CMD_IDENT:
                        N.command.`end` = S.i
                        N.command.value &= $`char`

                        # Note: When escaping anything but a dot do not
                        # include the '\' as it is not needed. For example,
                        # if the command is 'com\mand\.name' we should return
                        # 'command\.name' and not 'com\mand\.name'.
                        if `char` == '\\':
                            let nchar = if S.i + 1 < l: text[S.i + 1] else: '\0'

                            # nchar must exist else escaping nothing.
                            if nchar == '\0': error(S, currentSourcePath, 10)

                            # Only dots can be escaped.
                            if nchar != '.':
                                error(S, currentSourcePath, 10)

                                # Remove last escape char as it isn't needed.
                                let command = N.command.value[0 .. ^2]
                                N.command.value = command
                    elif `char` in C_SPACES:
                        state = "chain-wsb"
                        forward(S)
                        continue
                    elif `char` == '=':
                        state = "assignment"
                        rollback(S)
                    elif `char` == ',':
                        state = "delimiter"
                        rollback(S)
                    else: error(S, currentSourcePath)

            of "chain-wsb":
                if `char` notin C_SPACES:
                    if `char` == '=':
                        state = "assignment"
                        rollback(S)
                    elif `char` == ',':
                        state = "delimiter"
                        rollback(S)
                    else: error(S, currentSourcePath)

            of "assignment":
                N.assignment.start = S.i
                N.assignment.`end` = S.i
                N.assignment.value = $`char`
                state = "value-wsb"

            of "delimiter":
                N.delimiter.start = S.i
                N.delimiter.`end` = S.i
                N.delimiter.value = $`char`
                state = "eol-wsb"

            of "value-wsb":
                if `char` notin C_SPACES:
                    state = "value"
                    rollback(S)

            of "value":
                # Note: Intermediary step - remove it?
                if `char` notin C_CMD_VALUE: error(S, currentSourcePath)
                state = if `char` == '[': "open-bracket" else: "oneliner"
                rollback(S)

            of "open-bracket":
                # Note: Intermediary step - remove it?
                N.brackets.start = S.i
                N.brackets.value = $`char`
                N.value.value = $`char`
                state = "open-bracket-wsb"

            of "open-bracket-wsb":
                if `char` notin C_SPACES:
                    state = "close-bracket"
                    rollback(S)

            of "close-bracket":
                if `char` != ']': error(S, currentSourcePath)
                N.brackets.`end` = S.i
                N.value.value &= $`char`
                state = "eol-wsb"

            of "oneliner":
                tracer.trace(S, "flag") # Trace parser.
                N.flags.add(p_flag(S, "oneliner"))

            of "eol-wsb":
                if `char` notin C_SPACES: error(S, currentSourcePath)

            else: discard

        forward(S)

    add(S, N) # Add flags below.
    for n in N.flags: add(S, n)

    # If scope is created store ref to Node object.
    if N.value.value == "[": S.scopes.command = N
