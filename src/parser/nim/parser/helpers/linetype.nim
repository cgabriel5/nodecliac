import std/tables

import ../helpers/types
import charsets

# Determine line's line type.
#
# @param  {object} S - State object.
# @param  {char} char - The loop's current character.
# @param  {char} nchar - The loop's next character.
# @return {string} - The line's type.
proc linetype*(S: State, `char`, nchar: char): string =
    let text = S.text

    const types = {
        C_SEMICOLON: "terminator", # End parsing.
        C_NUMSIGN: "comment",
        C_DOLLARSIGN: "variable",
        C_ATSIGN: "setting",
        C_HYPHEN: "flag",
        C_RPAREN: "close-brace",
        C_RBRACKET: "close-brace"
    }.toTable

    var line_type = types.getOrDefault(`char`, "")

    # Line type overrides for: command, option, default.
    if line_type == "" and `char` in C_CMD_IDENT_START: line_type = "command"
    if line_type == "flag":
        if nchar != C_NULLB and nchar in C_SPACES: line_type = "option"
    elif line_type == "command":
        let keyword = text[S.i .. S.i + 6]
        if keyword in C_KW_ALL: line_type = "flag"

    return line_type
