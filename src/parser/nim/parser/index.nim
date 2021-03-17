import std/tables

import tools/[acdef, formatter]
import parsers/[command, flag, option, close_brace]
import parsers/[comment, newline, setting, variable]
import helpers/[charsets, types, brace_checks, error]
import helpers/[linetype, specificity, tracer, forward]

proc parser*(action, text, cmdname, source: string,
            fmt: tuple, trace, igc, test: bool): tuple =
    var S = state(action, cmdname, text, source, fmt, trace, igc, test)
    var ltype = ""

    let l = S.l; var `char`, nchar: char
    while S.i < l:
        `char` = text[S.i]
        nchar = if S.i + 1 < l: text[S.i + 1] else: C_NULLB

        # Handle newlines.
        if `char` in C_NL:
            p_newline(S)
            forward(S)
            continue

        # Handle inline comment.
        if `char` == C_NUMSIGN and S.sol_char != C_NULLB:
            tracer.trace(S, "comment")
            p_comment(S, true)
            forward(S)
            continue

        # Store line start index.
        if not S.tables.linestarts.hasKey(S.line):
            S.tables.linestarts[S.line] = S.i

        # Start parsing at first non-ws character.
        if S.sol_char == C_NULLB and `char` notin C_SPACES:
            S.sol_char = `char`

            # Sol char must be allowed.
            if `char` notin C_SOL: error(S, 10)

            ltype = linetype(S, `char`, nchar)
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

    if action == "make": result = acdef(S, cmdname)
    else: result = formatter(S)
