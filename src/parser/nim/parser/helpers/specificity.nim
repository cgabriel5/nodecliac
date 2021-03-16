import std/tables

import error
import ../helpers/types

# Validate line specificity.
#
# @param  {object} S - State object.
# @param  {string} line_type - The line's line type.
# @return - Nothing is returned.
proc specificity*(S: State, line_type: string, parserfile: string) =
    # Note: [Hierarchy lookup table] The higher the number the higher its
    # precedence. Therefore: command > flag > option. Variables, settings,
    # and command chains have the same precedence as they are same-level
    # defined (cannot be nested). Comments can be placed anywhere so
    # they don't have a listed precedence.
    const SPECF = {
        "setting": 3,
        "variable": 3,
        "command": 3,
        "flag": 2,
        "option": 1,
        "comment": 0
    }.toTable

    let line_specf = SPECF.getOrDefault(line_type, 0)
    let flag_scope = S.scopes.flag.node
    let command_scope = S.scopes.command.node

    # Note: When in a scope, scope's specificity trumps line's specificity.
    var state_specf = S.specf
    if flag_scope != "": state_specf = SPECF["flag"]
    elif command_scope != "": state_specf = SPECF["command"]

    # Error when specificity is invalid.
    if state_specf > 0 and state_specf < line_specf: error(S, parserfile, 12)
    S.specf = line_specf
