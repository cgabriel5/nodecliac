import flag
import ../../utils/strutil
import ../helpers/[tree_add, types, charsets]
import ../helpers/[error, tracer, forward, rollback, brace_checks]

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
    var state = Command
    var N = node(nkCommand, S)
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
    proc cescape(c: char, isgroup: bool, l: int, G: Group) =
        # Note: When escaping anything but a dot do not
        # include the '\' as it is not needed. For example,
        # if the command is 'com\mand\.name' we should return
        # 'command\.name' and not 'com\mand\.name'.
        if c == C_ESCAPE:
            let n = if S.i + 1 < l: S.text[S.i + 1] else: C_NULLB

            # n must exist else escaping nothing.
            if n == C_NULLB: error(S, 10)

            # Only dots can be escaped.
            if n != C_DOT:
                error(S, 10)

                # Remove last escape char as it isn't needed.
                if isgroup: G.command = G.command[0 .. ^2]
                else: N.command.value = N.command.value[0 .. ^2]

    let l = S.l; var c, p: char
    while S.i < l:
        p = c
        c = S.text[S.i]

        if c in C_NL:
            rollback(S)
            N.stop = S.i
            break # Stop at nl char.

        if c == C_NUMSIGN and p != C_ESCAPE:
            rollback(S)
            N.stop = S.i
            break

        case (state):
            of Command:
                if N.command.value == "":
                    if c notin C_CMD_IDENT_START : error(S)

                    N.command.start = S.i
                    N.command.stop = S.i
                    N.command.value &= $c

                    # Once a wildcard (all) char is found change state.
                    if c == C_ASTERISK: state = ChainWsb
                else:
                    if c in C_CMD_IDENT:
                        N.command.stop = S.i
                        N.command.value &= $c
                        cescape(c, false, l, G)
                    elif c in C_SPACES:
                        state = ChainWsb
                        forward(S)
                        continue
                    elif c == C_EQUALSIGN:
                        state = Assignment
                        rollback(S)
                    elif c == C_COMMA:
                        state = Delimiter
                        rollback(S)
                    elif c == C_LCURLY:
                        state = GroupOpen
                        rollback(S)
                    else: error(S)

            of ChainWsb:
                if c notin C_SPACES:
                    if c == C_EQUALSIGN:
                        state = Assignment
                        rollback(S)
                    elif c == C_COMMA:
                        state = Delimiter
                        rollback(S)
                    else: error(S)

            of Assignment:
                N.assignment.start = S.i
                N.assignment.stop = S.i
                N.assignment.value = $c
                state = ValueWsb

            of Delimiter:
                N.delimiter.start = S.i
                N.delimiter.stop = S.i
                N.delimiter.value = $c
                state = EolWsb

            of ValueWsb:
                if c notin C_SPACES:
                    state = Value
                    rollback(S)

            of Value:
                # Note: Intermediary step - remove it?
                if c notin C_CMD_VALUE: error(S)
                state = if c == C_LBRACKET: OpenBracket else: Oneliner
                rollback(S)

            of OpenBracket:
                # Note: Intermediary step - remove it?
                N.brackets.start = S.i
                N.brackets.value = $c
                N.value.value = $c
                state = OpenBracketWsb

            of OpenBracketWsb:
                if c notin C_SPACES:
                    state = CloseBracket
                    rollback(S)

            of CloseBracket:
                if c != C_RBRACKET: error(S)
                N.brackets.stop = S.i
                N.value.value &= $c
                state = EolWsb

            of Oneliner:
                tracer.trace(S, LTFlag) # Trace parser.

                let fN = p_flag(S, "oneliner")
                # Add alias node if it exists.
                if fN.alias.value != "":
                    let cN = node(nkFlag, S)
                    cN.hyphens.value = "-"
                    cN.delimiter.value = ","
                    cN.name.value = fN.alias.value
                    cN.singleton = true
                    cN.boolean.value = fN.boolean.value
                    cN.assignment.value = fN.assignment.value
                    cN.alias.value = cN.name.value
                    N.flags.add(cN)

                    # Add context node for mutual exclusivity.
                    let xN = node(nkFlag, S)
                    xN.value.value = "\"{" & fN.name.value & "|" & fN.alias.value & "}\""
                    xN.keyword.value = "context"
                    xN.singleton = false
                    xN.virtual = true
                    xN.args.add(xN.value.value)
                    N.flags.add(xN)
                N.flags.add(fN)

            of EolWsb:
                if c notin C_SPACES: error(S)

            # Command group states

            of GroupOpen:
                N.command.stop = S.i
                N.command.value &= (if not isformatting: "?" else: $c)

                state = GroupWsb

                G.start = S.column
                G.commands.add(@[])
                G.active = true

            of GroupWsb:
                if G.command != "": G.commands[^1].add(G.command)
                G.command = ""

                if c notin C_SPACES:
                    if c in C_CMD_GRP_IDENT_START:
                        state = GroupCommand
                        rollback(S)
                    elif c == C_COMMA:
                        state = GroupDelimiter
                        rollback(S)
                    elif c == C_RCURLY:
                        state = GroupClose
                        rollback(S)
                    else: error(S)

            of GroupCommand:
                if G.command == "":
                    if c notin C_CMD_GRP_IDENT_START: error(S)

                    var token: Token; token = ("command", S.column)
                    G.tokens.add(token)
                    N.command.stop = S.i
                    G.command &= $c
                    if isformatting: N.command.value &= $c
                else:
                    if c in C_CMD_IDENT:
                        N.command.stop = S.i
                        G.command &= $c
                        if isformatting: N.command.value &= $c
                        cescape(c, true, l, G)
                    elif c in C_SPACES:
                        state = GroupWsb
                        continue
                    elif c == C_COMMA:
                        state = GroupDelimiter
                        rollback(S)
                    elif c == C_RCURLY:
                        state = GroupClose
                        rollback(S)
                    else: error(S)

            of GroupDelimiter:
                N.command.stop = S.i
                if isformatting: N.command.value &= $c

                let ll = G.tokens.len
                if ll == 0 or (ll != 0 and G.tokens[^1][0] == "delimiter"):
                    error(S, 12)

                if G.command != "": G.commands[^1].add(G.command)
                var token: Token; token = ("delimiter", S.column)
                G.tokens.add(token)
                G.command = ""
                state = GroupWsb

            of GroupClose:
                N.command.stop = S.i
                if isformatting: N.command.value &= $c

                if G.command != "": G.commands[^1].add(G.command)
                if G.commands[^1].len == 0:
                    S.column = G.start
                    error(S, 11) # Empty command group.
                if G.tokens[^1][0] == "delimiter":
                    S.column = G.tokens[^1][1]
                    error(S, 12) # Trailing delimiter.

                G.active = false
                G.command = ""
                state = Command

            else: discard

        forward(S)

    if G.active:
        S.column = G.start
        error(S, 13) # Command group was left unclosed.

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
