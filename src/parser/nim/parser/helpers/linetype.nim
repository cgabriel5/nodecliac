from tables import toTable, hasKey, `[]`, `$`

from ../helpers/types import State
from charsets import C_LETTERS, C_SPACES

# Determine line's line type.
#
# @param  {object} S - State object.
# @param  {char} char - The loop's current character.
# @param  {char} nchar - The loop's next character.
# @return {string} - The line's type.
proc linetype*(S: State, `char`, nchar: char): string =
    let text = S.text

    const types = {
        ';': "terminator", # End parsing.
        '#': "comment",
        '$': "variable",
        '@': "setting",
        '-': "flag",
        ')': "close-brace",
        ']': "close-brace"
    }.toTable

    var line_type = if types.hasKey(`char`): types[`char`] else: ""

    # Line type overrides for: command, option, default.
    if line_type == "" and `char` in C_LETTERS: line_type = "command"
    if line_type == "flag":
        if nchar != '\0' and nchar in C_SPACES: line_type = "option"
    elif line_type == "command":
        if text[S.i .. S.i + 6] == "default": line_type = "flag"

    return line_type
