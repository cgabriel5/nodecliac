import std/tables

import error
import ../helpers/types

# Checks command/flag brace scopes are properly closed.
#
# @param  {object} S - State object.
# @param  {object} N - Node object.
# @param  {string} check - The check to run.
# @return - Nothing is returned.
proc bracechecks*(S: State, N: Node = Node(), check: string) =
    case check:
    # Note: Error if pre-existing command scope exists.
    # Command can't be declared inside a command scope.
    of "pre-existing-cs":
        if S.scopes.command.kind != nkEmpty: error(S, 10)

    # Note: Reset existing scope. If no scope exists
    # the closing brace was wrongly used so error.
    of "reset-scope":
        let t = if N.brace.value == "]": nkCommand else: nkFlag
        if t == nkCommand and S.scopes.command.kind != nkEmpty:
            S.scopes.command = Node()
        elif t == nkFlag and S.scopes.flag.kind != nkEmpty:
            S.scopes.flag = Node()
        else: error(S, 11)

    # Note: Error if scope was left unclosed.
    of "post-standing-scope":
        let scope = (
            if S.scopes.command.kind != nkEmpty: S.scopes.command
            else: S.scopes.flag
        )

        if scope.kind != nkEmpty:
            let brackets_start = scope.brackets.start
            let linestart = S.tables.linestarts[scope.line]

            S.column = brackets_start - linestart + 1 # Point to bracket.
            S.line = scope.line # Reset to line of unclosed scope.
            error(S, 12)

    # Note: Error if pre-existing flag scope exists.
    # Flag option declared out-of-scope.
    of "pre-existing-fs":
        if S.scopes.flag.kind == nkEmpty:
            let linestart = S.tables.linestarts[S.line]

            S.column = S.i - linestart + 1 # Point to bracket.
            error(S, 13)
