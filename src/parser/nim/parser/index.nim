import std/tables

import tools/[acdef, formatter]
import parsers/[command, flag, option, close_brace]
import parsers/[comment, newline, setting, variable]
import helpers/[charsets, types, brace_checks, error]
import helpers/[linetype, specificity, tracer, forward]

proc parser*(action, text, cmdname, source: string,
            fmt: tuple, trace, igc, test: bool): tuple =
    var S = state(action, cmdname, text, source, fmt, trace, igc, test)
    var ltype: LineType

    let l = S.l; var c, n: char
    while S.i < l:
        c = text[S.i]
        n = if S.i + 1 < l: text[S.i + 1] else: C_NULLB

        # Handle newlines.
        if c in C_NL:
            p_newline(S)
            forward(S)
            continue

        # Handle inline comment.
        if c == C_NUMSIGN and S.sol_char != C_NULLB:
            tracer.trace(S, LTComment)
            p_comment(S, true)
            forward(S)
            continue

        # Store line start index.
        if S.line notin S.tables.linestarts:
            S.tables.linestarts[S.line] = S.i

        # Start parsing at first non-ws character.
        if S.sol_char == C_NULLB and c notin C_SPACES:
            S.sol_char = c

            # Sol char must be allowed.
            if c notin C_SOL: error(S, 10)

            ltype = linetype(S, c, n)
            if ltype == LTTerminator: break

            specificity(S, ltype, currentSourcePath)

            tracer.trace(S, ltype)
            case (ltype):
            of LTComment: p_comment(S)
            of LTSetting: p_setting(S)
            of LTVariable: p_variable(S)
            of LTCommand: p_command(S)
            of LTFlag: discard p_flag(S, isoneliner = "")
            of LTOption: discard p_option(S)
            of LTCloseBrace: p_closebrace(S)
            else: discard

        forward(S)

    # Error if cc scope exists post-parsing.
    bracechecks(S, check = "post-standing-scope")

    if action == "make": result = acdef(S, cmdname)
    else: result = formatter(S)
