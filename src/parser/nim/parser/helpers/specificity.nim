import std/tables

import error
import ../helpers/types

# Validate line specificity.
#
# @param  {object} S - State object.
# @param  {enum} line_type - The line's line type.
# @return - Nothing is returned.
proc specificity*(S: State, line_type: LineType, parserfile: string) =
    # Note: [Hierarchy lookup table] The higher the number the higher its
    # precedence. Therefore: command > flag > option. Variables, settings,
    # and command chains have the same precedence as they are same-level
    # defined (cannot be nested). Comments can be placed anywhere so
    # they don't have a listed precedence.
    const SPECF = {
        LTSetting: 3,
        LTVariable: 3,
        LTCommand: 3,
        LTFlag: 2,
        LTOption: 1,
        LTComment: 0
    }.toTable

    let line_specf = SPECF.getOrDefault(line_type, 0)
    let flag_scope = S.scopes.flag.node
    let command_scope = S.scopes.command.node

    # Note: When in a scope, scope's specificity trumps line's specificity.
    var state_specf = S.specf
    if flag_scope != "": state_specf = SPECF[LTFlag]
    elif command_scope != "": state_specf = SPECF[LTCommand]

    # Error when specificity is invalid.
    if state_specf > 0 and state_specf < line_specf: error(S, 12)
    S.specf = line_specf
