import std/tables

import ../helpers/types
import charsets

# Determine line's line type.
#
# @param  {object} S - State object.
# @param  {char} c - The loop's current character.
# @param  {char} n - The loop's next character.
# @return {enum} - The line's type.
proc linetype*(S: State, c, n: char): LineType =
    let text = S.text

    const types = {
        C_SEMICOLON: LTTerminator, # End parsing.
        C_NUMSIGN: LTComment,
        C_DOLLARSIGN: LTVariable,
        C_ATSIGN: LTSetting,
        C_HYPHEN: LTFlag,
        C_RPAREN: LTCloseBrace,
        C_RBRACKET: LTCloseBrace
    }.toTable

    var line_type = types.getOrDefault(c, LTSkip)

    # Line type overrides for: command, option, default.
    if line_type == LTSkip and c in C_CMD_IDENT_START:
        line_type = LTCommand
    if line_type == LTFlag:
        if n != C_NULLB and n in C_SPACES:
            line_type = LTOption
    elif line_type == LTCommand:
        let keyword = text[S.i .. S.i + 6]
        if keyword in C_KW_ALL: line_type = LTFlag

    return line_type
