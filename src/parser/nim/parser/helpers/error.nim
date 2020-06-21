from strformat import fmt
from re import re, replace
from strutils import split, join
from os import DirSep, splitFile, extractFilename
from tables import toTable, initTable, `[]=`, `[]`, `$`

from ../helpers/types import State
import ../../utils/chalk

var tb = initTable[int, string]()
var errors = {
    "*": tb,
    "index": tb,
    "command": tb,
    "comment": tb,
    "flag": tb,
    "option": tb,
    "variable": tb,
    "setting": tb,
    "close_brace": tb,
    "brace_checks": tb,
    "template_string": tb,
    "validate": tb,
    "vcontext": tb
}.toTable
errors["*"][0] = "Syntax: Unexpected character"
errors["index"][10] = "Illegal start-of-line character"
errors["index"][12] = "Check line specificity order"
errors["command"][10] = "Illegal escape sequence"
errors["flag"][10] = "Flag declared out of scope"
errors["flag"][11] = "Flag declared within flag scope"
errors["brace_checks"][10] = "Command declared out of scope"
errors["brace_checks"][11] = "Can't close an unopened command scope"
errors["brace_checks"][12] = "Unclosed scope"
errors["brace_checks"][13] = "Flag option declared out of scope"
errors["validate"][10] = "Improperly quoted string"
errors["validate"][11] = "String cannot be empty"
errors["validate"][12] = "Undefined variable"
errors["validate"][13] = "Illegal command-flag syntax"
errors["validate"][14] = "Useless delimiter"
errors["validate"][15] = "Illegal list syntax"
errors["vcontext"][14] = "Useless delimiter"
errors["vcontext"][16] = "Missing flag conditions"
errors["vcontext"][17] = "Unclosed brace"

# Print error and kill process.
#
# @param  {object} S - State object.
# @param  {number} code - Error code.
# @param  {string} parserfile - Path of parser issuing error.
# @return - Nothing is returned.
proc error*(S: State, parserfile: string, code: int = 0) =
    let line = S.line
    let column = S.column
    var source = S.args.source
    var parser = extractFilename(parserfile).replace(re"\.nim$")

    # if not code code = 0; # Use default if code doesn't exist.
    let error = if code == 0: errors["*"][code] else: errors[parser][code]

    # Replace '_' to '-' to match JS error.
    if '_' in parser: parser = parser.replace(re"_", "-")

    let pos = fmt"{line}:{column}".chalk("bold", "red")
    let einfo = "[" & "err".chalk("red") & fmt" {parser},{code}" & "]"

    # Truncate source file path if too long.
    var dirs = source.split($DirSep)
    if dirs.len >= 5:
        dirs = dirs[dirs.high - 2 .. ^1]
        source = "..." & dirs.join($DirSep)

    let filename = extractFilename(source).chalk("bold")
    let dirname = splitFile(source).dir

    echo fmt"{einfo} {dirname}/{filename}:{pos} — {error}"
    quit()
