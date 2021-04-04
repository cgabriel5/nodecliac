import std/[re, strutils, os, tables]

import ../helpers/[types, charsets]
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
    "vcontext": tb,
    "vtest": tb
}.toTable
errors["*"][0] = "Syntax: Unexpected character"
errors["index"][10] = "Illegal start-of-line character"
errors["index"][12] = "Check line specificity order"
errors["command"][10] = "Illegal escape sequence"
errors["command"][11] = "Empty command group"
errors["command"][12] = "Useless delimiter"
errors["command"][13] = "Unclosed command group"
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
errors["validate"][16] = "Keyword cannot be valueless"
errors["validate"][17] = "Illegal exclude"
errors["vcontext"][14] = "Useless delimiter"
errors["vcontext"][16] = "Missing flag conditions"
errors["vcontext"][17] = "Unclosed brace"
errors["vtest"][14] = "Useless delimiter"
errors["vtest"][15] = "Malformed test string"

# Print error and kill process. Programmatically gets the filename where
#     the error occurred (file name where function was called). This is
#     better than using `currentSourcePath` everywhere.
#
# @param  {object} S - State object.
# @param  {number} code - Error code.
# @param  {string} parserfile - Path of parser issuing error.
# @return - Nothing is returned.
template error*(S: State, code: int = 0, parserfile: string = "") =
    # [https://github.com/nim-lang/Nim/issues/7406]
    # [https://nim-lang.org/docs/system.html#instantiationInfo]
    # [https://stackoverflow.com/a/29472072]
    # [https://github.com/nim-lang/Nim/blob/devel/lib/system.nim#L1729]
    # [https://forum.nim-lang.org/t/4211#26241]
    # [https://forum.nim-lang.org/t/3199#20161]
    # let callfile = instantiationInfo(-1).filename # currentSourcePath
    let fullpath = (
        if parserfile.len != 0: parserfile
        else: instantiationInfo(-1, true).filename
    )

    let line = S.line
    let column = S.column
    var source = S.args.source
    var parser = extractFilename(fullpath).replace(re"\.nim$")

    # if not code code = 0; # Use default if code doesn't exist.
    let error = if code == 0: errors["*"][code] else: errors[parser][code]

    # Replace '_' to '-' to match JS error.
    if C_UNDERSCORE in parser: parser = parser.replace(re"_", "-")

    let pos = ($line & ":" & $column).chalk("bold", "red")
    let einfo = "[" & "err".chalk("red") & " " & parser & "," & $code & "]"

    # Truncate source file path if too long.
    var dirs = source.split($DirSep)
    if dirs.len >= 5:
        dirs = dirs[dirs.high - 2 .. ^1]
        source = "..." & dirs.join($DirSep)

    let filename = extractFilename(source).chalk("bold")
    let dirname = splitFile(source).dir

    echo einfo & " " & dirname & "/" & filename & ":" & pos & " — " & error
    quit()
