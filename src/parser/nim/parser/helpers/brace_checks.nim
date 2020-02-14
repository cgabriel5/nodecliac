from tables import `[]`, `$`

import error
from ../helpers/types import State, Node, node

# Checks command/flag brace scopes are properly closed.
#
# @param  {object} S - State object.
# @param  {object} N - Node object.
# @param  {string} check - The check to run.
# @return - Nothing is returned.
proc bracechecks*(S: var State, N: Node = Node(), check: string) =
    case (check):
        # Note: Error if pre-existing command scope exists.
        # Command can't be declared inside a command scope.
        of "pre-existing-cs":
            let scope = S.scopes.command.node
            if scope != "": error(S, currentSourcePath, 10)

        # Note: Reset existing scope. If no scope exists
        # the closing brace was wrongly used so error.
        of "reset-scope":
            let `type` = if N.brace.value == "]": "command" else: "flag"
            if `type` == "command":
                if S.scopes.command.node != "": S.scopes.command = Node()
            elif `type` == "flag":
                if S.scopes.flag.node != "": S.scopes.flag = Node()
            else: error(S, currentSourcePath, 11)

        # Note: Error if scope was left unclosed.
        of "post-standing-scope":
            let flag = S.scopes.flag
            let command = S.scopes.command
            let scope = if command.node != "": command else: flag

            if scope.node != "":
                let brackets_start = scope.brackets.start
                let linestart = S.tables.linestarts[scope.line]

                S.column = brackets_start - linestart + 1 # Point to bracket.
                S.line = scope.line # Reset to line of unclosed scope.
                error(S, currentSourcePath, 12)

        # Note: Error if pre-existing flag scope exists.
        # Flag option declared out-of-scope.
        of "pre-existing-fs":
            if S.scopes.flag.node == "":
                let linestart = S.tables.linestarts[S.line]

                S.column = S.i - linestart + 1 # Point to bracket.
                error(S, currentSourcePath, 13)
