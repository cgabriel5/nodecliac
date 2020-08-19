from ../helpers/tree_add import add
from ../helpers/types import State, Node, node
import ../helpers/[error, validate, forward, rollback]
from ../helpers/charsets import C_NL, C_SPACES, C_LETTERS, C_QUOTES,
    C_FLG_IDENT, C_KW_ALL, C_KD_STR

# ------------------------------------------------------------ Parsing Breakdown
# --flag
# --flag ?
# --flag =* "string"
# --flag =* 'string'
# --flag =  $(flag-command)
# --flag =  (flag-options-list)
#       | |                    ^-EOL-Whitespace-Boundary 3.
#       ^-^-Whitespace-Boundary 1/2.
# ^-Symbol.
#  ^-Name.
#        ^-Assignment.
#           ^-Value.
# ------------------------------------------------------------------------------
#
# @param  {object} S - State object.
# @param  {string} isoneliner - Whether to treat flag as a oneliner.
# @return {object} - Node object.
proc p_flag*(S: State, isoneliner: string): Node =
    let text = S.text
    var state = if text[S.i] == '-': "hyphen" else: "keyword"
    var stop = false # Flag: true - stops parser.
    var `end` = false # Flag: true - ends consuming chars.
    var `type` = "escaped"
    var N = node(S, "FLAG")
    var alias = false

    # If not a oneliner or no command scope, flag is being declared out of scope.
    if not (isoneliner != "" or S.scopes.command.node != ""): error(S, currentSourcePath, 10)

    # If flag scope already exists another flag cannot be declared.
    if S.scopes.flag.node != "": error(S, currentSourcePath, 11)

    let l = S.l; var `char`: char
    while S.i < l:
        `char` = text[S.i]

        if stop or `char` in C_NL:
            rollback(S)
            N.`end` = S.i
            break # Stop at nl char.

        case (state):
            of "hyphen":
                # [https://stackoverflow.com/a/25895905]
                # [https://stackoverflow.com/a/12281034]
                # RegEx to split on unescaped '|': /(?<=[^\\]|^|$)\|/

                if N.hyphens.value == "":
                    if `char` != '-': error(S, currentSourcePath)
                    N.hyphens.start = S.i
                    N.hyphens.`end` = S.i
                    N.hyphens.value = $`char`
                else:
                    if `char` != '-':
                        state = "name"
                        rollback(S)
                    else:
                        N.hyphens.`end` = S.i
                        N.hyphens.value &= $`char`

            of "keyword":
                const keyword_len = 6
                let endpoint = S.i + keyword_len
                let keyword = text[S.i .. endpoint]

                # Keyword must be allowed.
                if keyword notin C_KW_ALL: error(S, currentSourcePath)
                N.keyword.start = S.i
                N.keyword.`end` = endpoint
                N.keyword.value = keyword
                state = "keyword-spacer"

                # Note: Forward indices to skip keyword chars.
                S.i += keyword_len
                S.column += keyword_len

            of "keyword-spacer":
                if `char` notin C_SPACES: error(S, currentSourcePath)
                state = "wsb-prevalue"

            of "name":
                if N.name.value == "":
                    if `char` notin C_LETTERS: error(S, currentSourcePath)
                    N.name.start = S.i
                    N.name.`end` = S.i
                    N.name.value = $`char`
                else:
                    if `char` in C_FLG_IDENT:
                        N.name.`end` = S.i
                        N.name.value &= $`char`
                    elif `char` == ':' and not alias:
                        state = "alias"
                        rollback(S)
                    elif `char` == '=':
                        state = "assignment"
                        rollback(S)
                    elif `char` == ',':
                        state = "delimiter"
                        rollback(S)
                    elif `char` == '?':
                        state = "boolean-indicator"
                        rollback(S)
                    elif `char` == '|':
                        state = "pipe-delimiter"
                        rollback(S)
                    elif `char` in C_SPACES:
                        state = "wsb-postname"
                        rollback(S)
                    else: error(S, currentSourcePath)

            of "wsb-postname":
                if `char` notin C_SPACES:
                    if `char` == '=':
                        state = "assignment"
                        rollback(S)
                    elif `char` == ',':
                        state = "delimiter"
                        rollback(S)
                    elif `char` == '|':
                        state = "pipe-delimiter"
                        rollback(S)
                    else: error(S, currentSourcePath)

            of "boolean-indicator":
                N.boolean.start = S.i
                N.boolean.`end` = S.i
                N.boolean.value = $`char`
                state = "pipe-delimiter"

            of "alias":
                alias = true
                # Next char must also be a colon.
                let nchar = if S.i + 1 < l: text[S.i + 1] else: '\0'
                if nchar != ':': error(S, currentSourcePath)
                N.alias.start = S.i
                N.alias.`end` = S.i + 2

                let letter = if S.i + 2 < l: text[S.i + 2] else: '\0'
                if letter notin C_LETTERS:
                    S.i += 1
                    S.column += 1
                    error(S, currentSourcePath)

                N.alias.value = $letter
                state = "name"

                # Note: Forward indices to skip alias chars.
                S.i += 2
                S.column += 2

            of "assignment":
                N.assignment.start = S.i
                N.assignment.`end` = S.i
                N.assignment.value = $`char`
                state = "multi-indicator"

            of "multi-indicator":
                if `char` == '*':
                    N.multi.start = S.i
                    N.multi.`end` = S.i
                    N.multi.value = $`char`
                    state = "wsb-prevalue"
                else:
                    if `char` == '|': state = "pipe-delimiter"
                    elif `char` == ',': state = "delimiter"
                    else: state = "wsb-prevalue"
                    rollback(S)

            of "pipe-delimiter":
                # Note: If char is not a pipe or if the flag is not a oneliner
                # flag and there are more characters after the flag error.
                # Example:
                # * = [
                #      --help?|context "!help: #fge1"
                # ]
                if `char` != '|' or isoneliner == "": error(S, currentSourcePath)
                stop = true

            of "delimiter":
                N.delimiter.start = S.i
                N.delimiter.`end` = S.i
                N.delimiter.value = $`char`
                state = "eol-wsb"

            of "wsb-prevalue":
                if `char` notin C_SPACES:
                    let keyword = N.keyword.value notin C_KD_STR
                    if `char` == '|' and keyword: state = "pipe-delimiter"
                    elif `char` == ',': state = "delimiter"
                    else: state = "value"
                    rollback(S)

            of "value":
                let pchar = if S.i - 1 < l: text[S.i - 1] else: '\0'

                if N.value.value == "":
                    # Determine value type.
                    if `char` == '$': `type` = "command-flag"
                    elif `char` == '(': `type` = "list"
                    elif `char` in C_QUOTES: `type` = "quoted"

                    N.value.start = S.i
                    N.value.`end` = S.i
                    N.value.value = $`char`
                else:
                    if `char` == '|' and N.keyword.value notin C_KD_STR and pchar != '\\':
                        state = "pipe-delimiter"
                        rollback(S)
                    else:
                        # If flag is set and chars can still be consumed
                        # there is a syntax error. For example, string
                        # may be improperly quoted/escaped so error.
                        if `end`: error(S, currentSourcePath)

                        let isescaped = pchar != '\\'
                        if `type` == "escaped":
                            if `char` in C_SPACES and isescaped: `end` = true
                        elif `type` == "quoted":
                            let vfchar = N.value.value[0]
                            if `char` == vfchar and isescaped: `end` = true
                        N.value.`end` = S.i
                        N.value.value &= $`char`

            of "eol-wsb":
                if `char` notin C_SPACES: error(S, currentSourcePath)

            else: discard

        forward(S)

    # If scope is created store ref to Node object.
    if N.value.value == "(":
        N.brackets.start = N.value.start
        N.brackets.`end` = N.value.start
        N.brackets.value = N.value.value
        S.scopes.flag = N

    discard validate(S, N)

    if isoneliner == "":
        N.singleton = true

        # Add alias node if it exists.
        if N.alias.value != "":
            var cN = node(S, "FLAG")
            cN.hyphens.value = "-"
            cN.delimiter.value = ","
            cN.name.value = N.alias.value
            cN.singleton = true
            cN.boolean.value = N.boolean.value
            add(S, cN)
        add(S, N)

    return N
