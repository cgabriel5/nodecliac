from re import re, match
from "../helpers/types" import State, Node, node
import "../helpers/error"
import "../helpers/validate"
import "../helpers/forward"
import "../helpers/rollback"
from "../helpers/tree_add" import add
from "../helpers/patterns" import r_nl, r_space, r_letter, r_quote

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
proc p_flag*(S: var State, isoneliner: string): Node =
    var text = S.text
    var state = if text[S.i] == '-': "hyphen" else: "keyword"
    var stop = false # Flag: true - stops parser.
    var `end` = false # Flag: true - ends consuming chars.
    var `type` = "escaped"
    var N = node(S, "FLAG")

    # If not a oneliner or no command scope, flag is being declared out of scope.
    if not (isoneliner != "" or S.scopes.command.node != ""): error(S, currentSourcePath, 10)

    # If flag scope already exists another flag cannot be declared.
    if S.scopes.flag.node != "": error(S, currentSourcePath, 11)

    let i = S.i; let l = S.l; var `char`: char
    while S.i < S.l:
        `char` = text[S.i]

        if stop or match($`char`, r_nl):
            rollback(S)
            N.end = S.i
            break # Stop at nl char.

        case (state):
            of "hyphen":
                # [https://stackoverflow.com/a/25895905]
                # [https://stackoverflow.com/a/12281034]
                # RegEx to split on unescaped '|': /(?<=[^\\]|^|$)\|/

                if N.hyphens.value == "":
                    if $`char` != "-": error(S, currentSourcePath)
                    N.hyphens.start = S.i
                    N.hyphens.end = S.i
                    N.hyphens.value = $`char`
                else:
                    if $`char` != "-":
                        state = "name"
                        rollback(S)
                    else:
                        N.hyphens.end = S.i
                        N.hyphens.value &= $`char`

            of "keyword":
                const keyword_len = 6
                let keyword = text[S.i .. S.i + keyword_len]

                # If keyword isn't 'default', error.
                if keyword != "default": error(S, currentSourcePath)
                N.keyword.start = S.i
                N.keyword.end = S.i + keyword_len
                N.keyword.value = keyword
                state = "keyword-spacer"

                # Note: Forward indices to skip keyword chars.
                S.i = S.i + (keyword_len)
                S.column = S.column + (keyword_len)

            of "keyword-spacer":
                if not match($`char`, r_space): error(S, currentSourcePath)
                state = "wsb-prevalue"

            of "name":
                if N.name.value == "":
                    if not match($`char`, r_letter): error(S, currentSourcePath)
                    N.name.start = S.i
                    N.name.end = S.i
                    N.name.value = $`char`
                else:
                    if match($`char`, re"[-.a-zA-Z0-9]"):
                        N.name.end = S.i
                        N.name.value &= $`char`
                    elif $`char` == "=":
                        state = "assignment"
                        rollback(S)
                    elif $`char` == "?":
                        state = "boolean-indicator"
                        rollback(S)
                    elif $`char` == "|":
                        state = "pipe-delimiter"
                        rollback(S)
                    elif match($`char`, r_space):
                        state = "wsb-postname"
                        rollback(S)
                    else: error(S, currentSourcePath)

            of "wsb-postname":
                if not match($`char`, r_space):
                    if $`char` == "=":
                        state = "assignment"
                        rollback(S)
                    elif $`char` == "|":
                        state = "pipe-delimiter"
                        rollback(S)
                    else: error(S, currentSourcePath)

            of "boolean-indicator":
                N.boolean.start = S.i
                N.boolean.end = S.i
                N.boolean.value = $`char`
                state = "pipe-delimiter"

            of "assignment":
                N.assignment.start = S.i
                N.assignment.end = S.i
                N.assignment.value = $`char`
                state = "multi-indicator"

            of "multi-indicator":
                if $`char` == "*":
                    N.multi.start = S.i
                    N.multi.end = S.i
                    N.multi.value = $`char`
                    state = "wsb-prevalue"
                else:
                    if $`char` == "|": state = "pipe-delimiter"
                    else: state = "wsb-prevalue"
                    rollback(S)

            of "pipe-delimiter":
                if $`char` != "|": error(S, currentSourcePath)
                stop = true

            of "wsb-prevalue":
                if not match($`char`, r_space):
                    if $`char` == "|": state = "pipe-delimiter"
                    else: state = "value"
                    rollback(S)

            of "value":
                let pchar = if S.i - 1 < l: text[S.i - 1] else: '\0'

                if N.value.value == "":
                    # Determine value type.
                    if $`char` == "$": `type` = "command-flag"
                    elif $`char` == "(": `type` = "list"
                    elif match($`char`, r_quote): `type` = "quoted"

                    N.value.start = S.i
                    N.value.end = S.i
                    N.value.value = $`char`
                else:
                    if $`char` == "|" and $pchar != "\\":
                        state = "pipe-delimiter"
                        rollback(S)

                    # If flag is set and chars can still be consumed
                    # there is a syntax error. For example, string
                    # may be improperly quoted/escaped so error.
                    if `end`: error(S, currentSourcePath)

                    let isescaped = $pchar != "\\"
                    if `type` == "escaped":
                        if match($`char`, r_space) and isescaped: `end` = true
                    elif `type` == "quoted":
                        let vfchar = N.value.value[0]
                        if $`char` == $vfchar and isescaped: `end` = true
                    N.value.end = S.i
                    N.value.value &= $`char`

        forward(S)

    # If scope is created store ref to Node object.
    if N.value.value == "(":
        N.brackets.start = N.value.start
        N.brackets.end = N.value.start
        N.brackets.value = N.value.value
        S.scopes.flag = N

    discard validate(S, N)

    if isoneliner == "":
        N.singleton = true
        add(S, N)

    return N
