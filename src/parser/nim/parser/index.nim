from tables import `[]=`, `[]`, hasKey, `$`
from re import match
# import tools/formatter
from helpers/types import state
import helpers/[brace_checks, error, linetype, specificity, tracer, rollback]
from helpers/patterns import r_space, r_sol_char
import parsers/newline

proc parser*(action: string, text: string, cmdname: string, source: string,
    fmt: tuple, trace: bool, igc: bool, test: bool): int =
    var S = state(action, text, source, fmt, trace, igc, test)
    var linestarts = S.tables.linestarts
    # const stime = process.hrtime();
    var ltype = ""

    var i = S.i
    let l = S.l
    for i in countup(1, l - 1, 1):
        S.i = S.i + 1
        S.column = S.column + 1

        let `char` = text[S.i]
        var nchar: char
        if S.i + 1 < l: nchar = text[S.i + 1]

        # Handle newlines.
        if `char` == '\n':
            p_newline(S)
            continue

        # Store line start index.
        if not linestarts.hasKey(S.line): S.tables.linestarts[S.line] = S.i

        # Start parsing at first non-ws character.
        if S.sol_char == "" and not match($`char`, r_space):
            S.sol_char = $`char`

            # Sol char must be allowed.
            if not match($`char`, r_sol_char): error(S, currentSourcePath, 10)

            ltype = linetype(S, $`char`, $nchar)
            if ltype == "terminator": break

            specificity(S, ltype, currentSourcePath)

            tracer.trace(S, ltype)
            # require(`./parsers/${ltype}.js`)(S)

    # Error if cc scope exists post-parsing.
    bracechecks(S, check = "post-standing-scope")

    return 1

    # let res = {}
    # if (action === "format") res.formatted = formatter(S)
    # else res = require("./tools/acdef.js")(S, cmdname)
    # res.time = process.hrtime(stime)
    # return res
