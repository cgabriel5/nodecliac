from tables import `[]=`, `[]`, hasKey, `$`
from re import match
# import tools/formatter
from helpers/types import state
import helpers/[brace_checks, error, linetype, specificity, tracer, rollback, forward]
from helpers/patterns import r_space, r_sol_char
import parsers/[comment, newline, setting, variable, command, flag, option, close_brace]

proc parser*(action: string, text: string, cmdname: string, source: string,
    fmt: tuple, trace: bool, igc: bool, test: bool): int =
    var S = state(action, text, source, fmt, trace, igc, test)
    var ltype = ""

    let i = S.i; let l = S.l; var `char`, nchar: char
    while S.i < S.l:
        `char` = text[S.i]
        nchar = if S.i + 1 < l: text[S.i + 1] else: '\0'
        # [https://stackoverflow.com/a/18410258]

        # Handle newlines.
        if `char` == '\n':
            p_newline(S)
            forward(S)
            continue

        # Store line start index.
        if not S.tables.linestarts.hasKey(S.line):
            S.tables.linestarts[S.line] = S.i

        # Start parsing at first non-ws character.
        if S.sol_char == "" and not match($`char`, r_space):
            S.sol_char = $`char`

            # Sol char must be allowed.
            if not match($`char`, r_sol_char): error(S, currentSourcePath, 10)

            ltype = linetype(S, $`char`, $nchar)
            if ltype == "terminator": break

            specificity(S, ltype, currentSourcePath)

            tracer.trace(S, ltype)
            case (ltype):
            of "comment": p_comment(S)
            of "setting": p_setting(S)
            of "variable": p_variable(S)
            of "command": p_command(S)
            of "flag": discard p_flag(S, isoneliner = "")
            of "option": discard p_option(S)
            of "close-brace": p_closebrace(S)
            else: discard

        forward(S)

    # Error if cc scope exists post-parsing.
    bracechecks(S, check = "post-standing-scope")

    return 1

    # let res = {}
    # if (action === "format") res.formatted = formatter(S)
    # else res = require("./tools/acdef.js")(S, cmdname)
    # return res
