import ./helpers/[types]
import utils/[chalk]
import issue
import tables
import sets
import strutils
# from sets import incl

proc vsetting*(S: ParseState) =
    let token = S.lexerdata.tokens[S.tid]
    let start = token.start
    let `end` = token.`end`
    let line = token.line
    let index = token.start

    const settings = ["compopt", "filedir", "disable", "placehold", "test"]

    let setting = S.text[start + 1 .. `end`]

    # Warn if setting is not a supported setting.
    if setting notin settings:
        let message = "Unknown setting: '" & setting & "'"

        if line notin S.warnings:
            S.warnings[line] = @[]
        var warning: Warning
        warning = (S.filename, line, index - S.lexerdata.LINESTARTS[line], message)
        S.warnings[line].add(warning)
        S.warn_lines.incl(line)

proc vvariable*(S: ParseState) =
    let token = S.lexerdata.tokens[S.tid]
    let start = token.start
    # let `end` = token.`end`
    let line = token.line
    let index = token.start

    # Error when variable starts with a number.
    if S.text[start + 1].isDigit():
        var message = "Unexpected: '" & S.text[start] & "'"
        message &= "\n" & "Info".chalk("bold", "cyan") & ": Variable cannot begin with a number."
        issue_error(S.filename, line, index - S.lexerdata.LINESTARTS[line], message)

proc vstring*(S: ParseState) =
    let token = S.lexerdata.tokens[S.tid]
    let start = token.start
    let `end` = token.`end`
    let line = token.lines[0]
    let index = token.start

    # Warn when string is empty.
    # [TODO] Warn if string content is just whitespace?
    if `end` - start == 1:
        let message = "Empty string"

        if line notin S.warnings:
            S.warnings[line] = @[]
        var warning: Warning
        warning = (S.filename, line, index - S.lexerdata.LINESTARTS[line], message)
        S.warnings[line].add(warning)
        S.warn_lines.incl(line)

    # Error if string is unclosed.
    if token.lines[1] == -1:
        let message = "Unclosed string"
        issue_error(S.filename, line, index - S.lexerdata.LINESTARTS[line], message)

proc vsetting_aval*(S: ParseState) =
    let token = S.lexerdata.tokens[S.tid]
    let start = token.start
    let `end` = token.`end`
    let line = token.line
    let index = token.start

    let values = ["true", "false"]

    let value = S.text[start .. `end`]

    # Warn if values is not a supported values.
    if value notin values:
        let message = "Invalid setting value: '" & value & "'"
        issue_error(S.filename, line, index - S.lexerdata.LINESTARTS[line], message)
