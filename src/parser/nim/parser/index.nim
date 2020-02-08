from tables import `[]=`, `[]`, hasKey, `$`
from helpers/types import state

# const error = require("./helpers/error.js");
# const formatter = require("./tools/formatter.js");
from parsers.newline import p_newline # import parsers / [newline]
# const linetype = require("./helpers/line-type.js");
# const specificity = require("./helpers/specificity.js");
# const bracechecks = require("./helpers/brace-checks.js");
# const { r_sol_char, r_space } = require("./helpers/patterns.js");

proc parser*(action: string, text: string, cmdname: string, source: string,
    fmt: tuple, trace: bool, igc: bool, test: bool): int =
    var S = state(action, text, source, fmt, trace, igc, test)
    var linestarts = S.tables.linestarts
    # const stime = process.hrtime();
    var line_type = ""

    var i = S.i
    let l = S.l
    for i in countup(1, l - 1, 1):
        S.i = S.i + 1
        S.column = S.column + 1

        let char = text[S.i]
        var nchar: char
        if S.i + 1 < l: nchar = text[S.i + 1]

        # Handle newlines.
        if char == '\n':
            p_newline(S)
            continue

        # Store line start index.
        if not linestarts.hasKey(S.line): linestarts[S.line] = S.i

    return 1

    #     // Start parsing at first non-ws character.
    #     if (!S.sol_char && !r_space.test(char)) {
    #         S.sol_char = char;

    #         // Sol char must be allowed.
    #         if (!r_sol_char.test(char)) error(S, __filename, 10);

    #         line_type = linetype(S, char, nchar);
    #         if (line_type === "terminator") break;

    #         specificity(S, line_type);

    #         require("./helpers/trace.js")(S, line_type);
    #         require(`./parsers/${line_type}.js`)(S);
    #     }
    # }

    # // Error if cc scope exists post-parsing.
    # bracechecks(S, null, "post-standing-scope");

    # let res = {};
    # if (action === "format") res.formatted = formatter(S);
    # else res = require("./tools/acdef.js")(S, cmdname);
    # res.time = process.hrtime(stime);
    # return res;
