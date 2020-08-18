import flag
from ../helpers/tree_add import add
from ../helpers/types import State, Node, node
import ../helpers/[error, tracer, forward, rollback, brace_checks]
from ../helpers/charsets import C_NL, C_SPACES,
    C_CMD_IDENT_START, C_CMD_GRP_IDENT_START, C_CMD_IDENT, C_CMD_VALUE

from ../../utils/strutil import replaceOnce

# ------------------------------------------------------------ Parsing Breakdown
# program.command
# program.command ,
# program.command =
# program.command = [
# program.command = [ ]?
# program.command = --flag
# program.command.{ command , command } = --flag
#                | |
#                ^-^-Whitespace-Boundary 1/2
#                 ^-Group-Open
#                  ^-Group-Whitespace-Boundary
#                   ^Group-Command
#                           ^Group-Delimiter
#                                     ^-Group-Close
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
    let isformatting = S.args.action == "format"

    # Group state structures.
    type
        Group = ref object
            active: bool
            command: string
            start: int
            commands: seq[seq[string]]
            tokens: seq[tuple[`type`: string, index: int]]
        Token = tuple[`type`: string, index: int]
    var G = Group()

    # Error if cc scope exists (brace not closed).
    bracechecks(S, check = "pre-existing-cs")

    # Checks dot "."" delimiter escaping in command.
    #
    # @param  {string} char - The current loop iteration character.
    # @param  {boolean} isgroup - Whether command is part of a group.
    # @return {undefined} - Nothing is returned.
    proc cescape(`char`: char, isgroup: bool, l: int, G: Group) =
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
                if isgroup: G.command = G.command[0 .. ^2]
                else: N.command.value = N.command.value[0 .. ^2]

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

                    # Once a wildcard (all) char is found change state.
                    if `char` == '*': state = "chain-wsb"
                else:
                    if `char` in C_CMD_IDENT:
                        N.command.`end` = S.i
                        N.command.value &= $`char`
                        cescape(`char`, false, l, G)
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
                    elif `char` == '{':
                        state = "group-open"
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

            # Command group states

            of "group-open":
                N.command.`end` = S.i
                N.command.value &= (if not isformatting: "?" else: $`char`)

                state = "group-wsb"

                G.start = S.column
                G.commands.add(@[])
                G.active = true

            of "group-wsb":
                if G.command != "": G.commands[^1].add(G.command)
                G.command = ""

                if `char` notin C_SPACES:
                    if `char` in C_CMD_GRP_IDENT_START:
                        state = "group-command"
                        rollback(S)
                    elif `char` == ',':
                        state = "group-delimiter"
                        rollback(S)
                    elif `char` == '}':
                        state = "group-close"
                        rollback(S)
                    else: error(S, currentSourcePath)

            of "group-command":
                if G.command == "":
                    if `char` notin C_CMD_GRP_IDENT_START: error(S, currentSourcePath)

                    var token: Token; token = ("command", S.column)
                    G.tokens.add(token)
                    N.command.`end` = S.i
                    G.command &= $`char`
                    if isformatting: N.command.value &= $`char`
                else:
                    if `char` in C_CMD_IDENT:
                        N.command.`end` = S.i
                        G.command &= $`char`
                        if isformatting: N.command.value &= $`char`
                        cescape(`char`, true, l, G)
                    elif `char` in C_SPACES:
                        state = "group-wsb"
                        continue
                    elif `char` == ',':
                        state = "group-delimiter"
                        rollback(S)
                    elif `char` == '}':
                        state = "group-close"
                        rollback(S)
                    else: error(S, currentSourcePath)

            of "group-delimiter":
                N.command.`end` = S.i
                if isformatting: N.command.value &= $`char`

                let ll = G.tokens.len
                if ll == 0 or (ll != 0 and G.tokens[^1][0] == "delimiter"):
                    error(S, currentSourcePath, 12)

                if G.command != "": G.commands[^1].add(G.command)
                var token: Token; token = ("delimiter", S.column)
                G.tokens.add(token)
                G.command = ""
                state = "group-wsb"

            of "group-close":
                N.command.`end` = S.i
                if isformatting: N.command.value &= $`char`

                if G.command != "": G.commands[^1].add(G.command)
                if G.commands[^1].len == 0:
                    S.column = G.start
                    error(S, currentSourcePath, 11) # Empty command group.
                if G.tokens[^1][0] == "delimiter":
                    S.column = G.tokens[^1][1]
                    error(S, currentSourcePath, 12) # Trailing delimiter.

                G.active = false
                G.command = ""
                state = "command"

            else: discard

        forward(S)

    if G.active:
        S.column = G.start
        error(S, currentSourcePath, 13) # Command group was left unclosed.

    # Expand command groups.
    if not isformatting and G.commands.len != 0:
        var commands: seq[string] = @[]
        # Loop over each group command group and replace placeholder.
        for group in G.commands:
            if commands.len == 0:
                for cmd in group:
                    commands.add(N.command.value.replaceOnce("?", cmd))
            else:
                var tmp_commands: seq[string] = @[]
                for command in commands:
                    for cmd in group:
                        tmp_commands.add(command.replaceOnce("?", cmd))
                commands = tmp_commands

        # Create individual Node objects for each expanded command chain.
        let l = commands.len
        for i, command in commands:
            # [https://forum.nim-lang.org/t/5539#34534]
            # [https://rosettacode.org/wiki/Deepcopy#Nim]
            var cN = deepCopy(N)
            cN.command.value = commands[i]
            cN.delimiter.value = ""
            cN.assignment.value = ""
            let aval = N.assignment.value
            if N.delimiter.value != "" or aval != "":
                if aval != "" and l - 1 == i: cN.assignment.value = "="
                else: cN.delimiter.value = ","

            add(S, cN) # Add flags below.
            for n in cN.flags: add(S, n)
    else:
        add(S, N) # Add flags below.
        for n in N.flags: add(S, n)

    # If scope is created store ref to Node object.
    if N.value.value == "[": S.scopes.command = N
