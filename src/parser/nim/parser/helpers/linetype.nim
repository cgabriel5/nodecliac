from re import match
from tables import toTable, hasKey, `[]`, `$`

from ../helpers/types import State
from patterns import r_space, r_letter

# Determine line's line type.
#
# @param  {object} S - State object.
# @param  {char} char - The loop's current character.
# @param  {char} nchar - The loop's next character.
# @return {string} - The line's type.
proc linetype*(S: State, char: string, nchar: string): string =
    let text = S.text

    const types = {
        ";": "terminator", # End parsing.
        "#": "comment",
        "$": "variable",
        "@": "setting",
        "-": "flag",
        ")": "close-brace",
        "]": "close-brace"
    }.toTable

    let echar = ""
    var line_type = if types.hasKey(char): types[char] else: echar

    # Line type overrides for: command, option, default.
    if line_type == "" and match(char, r_letter): line_type = "command"
    if line_type == "flag":
        if nchar != "" and match(nchar, r_space): line_type = "option"
    elif line_type == "command":
        if text[S.i .. S.i + 6] == "default": line_type = "flag"

    return line_type
