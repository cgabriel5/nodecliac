from os import DirSep, splitFile, extractFilename
from re import re, replace
from strformat import fmt
from strutils import split, join
from tables import toTable, initTable, `[]=`, `[]`, `$`
from "../helpers/types" import State
import "../../utils/chalk"

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
    "close-brace": tb,
    "brace-checks": tb,
    "template-string": tb,
    "validate": tb
}.toTable
errors["*"][0] = "Syntax: Unexpected character"
errors["index"][10] = "Illegal start-of-line character"
errors["index"][12] = "Check line specificity order"
errors["command"][10] = "Illegal escape sequence"
errors["flag"][10] = "Flag declared out of scope"
errors["flag"][11] = "Flag declared within flag scope"
errors["brace-checks"][10] = "Command declared out of scope"
errors["brace-checks"][11] = "Can't close an unopened command scope"
errors["brace-checks"][12] = "Unclosed scope"
errors["brace-checks"][13] = "Flag option declared out of scope"
errors["validate"][10] = "Improperly quoted string"
errors["validate"][11] = "String cannot be empty"
errors["validate"][12] = "Undefined variable"
errors["validate"][13] = "Illegal command-flag syntax"
errors["validate"][14] = "Useless comma delimiter"
errors["validate"][15] = "Illegal list syntax"

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
    let parser = extractFilename(parserfile).replace(re"\.nim$")

    # if not code code = 0; # Use default if code doesn't exist.
    # let error = errors[code ? parser : "*"][code];
    let error = if code == 0: errors["*"][code] else: errors[parser][code]

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
    if true: quit()
