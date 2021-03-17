import std/tables

import ../helpers/[tree_add, types, charsets]
import ../helpers/[error, validate, forward, rollback]

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
    var state = if text[S.i] == C_HYPHEN: Hyphen else: Keyword
    var stop = false # Flag: true - stops parser.
    var `type` = "escaped"
    var N = node(nkFlag, S)
    var alias = false
    var qchar: char
    var comment = false
    var braces: seq[int] = @[]

    # If not a oneliner or no command scope, flag is being declared out of scope.
    if not (isoneliner != "" or S.scopes.command.node != ""): error(S, currentSourcePath, 10)

    # If flag scope already exists another flag cannot be declared.
    if S.scopes.flag.node != "": error(S, currentSourcePath, 11)

    let l = S.l; var c, p: char
    while S.i < l:
        p = c
        c = text[S.i]

        if stop or c in C_NL:
            rollback(S)
            N.stop = S.i
            break # Stop at nl char.

        if c == C_NUMSIGN and p != C_ESCAPE and (state != Value or comment):
            rollback(S)
            N.stop = S.i
            break

        case (state):
            of Hyphen:
                # [https://stackoverflow.com/a/25895905]
                # [https://stackoverflow.com/a/12281034]
                # RegEx to split on unescaped C_PIPE: /(?<=[^\\]|^|$)\|/

                if N.hyphens.value == "":
                    if c != C_HYPHEN: error(S, currentSourcePath)
                    N.hyphens.start = S.i
                    N.hyphens.stop = S.i
                    N.hyphens.value = $c
                else:
                    if c != C_HYPHEN:
                        state = Name
                        rollback(S)
                    else:
                        N.hyphens.stop = S.i
                        N.hyphens.value &= $c

            of Keyword:
                const keyword_len = 6
                let endpoint = S.i + keyword_len
                let keyword = text[S.i .. endpoint]

                # Keyword must be allowed.
                if keyword notin C_KW_ALL: error(S, currentSourcePath)
                N.keyword.start = S.i
                N.keyword.stop = endpoint
                N.keyword.value = keyword
                state = KeywordSpacer

                # Note: Forward indices to skip keyword chars.
                S.i += keyword_len
                S.column += keyword_len

            of KeywordSpacer:
                if c notin C_SPACES: error(S, currentSourcePath)
                state = WsbPrevalue

            of Name:
                if N.name.value == "":
                    if c notin C_LETTERS: error(S, currentSourcePath)
                    N.name.start = S.i
                    N.name.stop = S.i
                    N.name.value = $c
                else:
                    if c in C_FLG_IDENT:
                        N.name.stop = S.i
                        N.name.value &= $c
                    elif c == C_COLON and not alias:
                        state = Alias
                        rollback(S)
                    elif c == C_EQUALSIGN:
                        state = Assignment
                        rollback(S)
                    elif c == C_COMMA:
                        state = Delimiter
                        rollback(S)
                    elif c == C_QMARK:
                        state = BooleanIndicator
                        rollback(S)
                    elif c == C_PIPE:
                        state = PipeDelimiter
                        rollback(S)
                    elif c in C_SPACES:
                        state = WsbPostname
                        rollback(S)
                    else: error(S, currentSourcePath)

            of WsbPostname:
                if c notin C_SPACES:
                    if c == C_EQUALSIGN:
                        state = Assignment
                        rollback(S)
                    elif c == C_COMMA:
                        state = Delimiter
                        rollback(S)
                    elif c == C_PIPE:
                        state = PipeDelimiter
                        rollback(S)
                    else: error(S, currentSourcePath)

            of BooleanIndicator:
                N.boolean.start = S.i
                N.boolean.stop = S.i
                N.boolean.value = $c
                state = PipeDelimiter

            of Alias:
                alias = true
                # Next char must also be a colon.
                let n = if S.i + 1 < l: text[S.i + 1] else: C_NULLB
                if n != C_COLON: error(S, currentSourcePath)
                N.alias.start = S.i
                N.alias.stop = S.i + 2

                let letter = if S.i + 2 < l: text[S.i + 2] else: C_NULLB
                if letter notin C_LETTERS:
                    S.i += 1
                    S.column += 1
                    error(S, currentSourcePath)

                N.alias.value = $letter
                state = Name

                # Note: Forward indices to skip alias chars.
                S.i += 2
                S.column += 2

            of Assignment:
                N.assignment.start = S.i
                N.assignment.stop = S.i
                N.assignment.value = $c
                state = MultiIndicator

            of MultiIndicator:
                if c == C_ASTERISK:
                    N.multi.start = S.i
                    N.multi.stop = S.i
                    N.multi.value = $c
                    state = WsbPrevalue
                else:
                    if c == C_PIPE: state = PipeDelimiter
                    elif c == C_COMMA: state = Delimiter
                    else: state = WsbPrevalue
                    rollback(S)

            of PipeDelimiter:
                if c notin C_SPACES:
                    # Note: If char is not a pipe or if the flag is not a
                    # oneliner flag and there are more characters after the
                    # flag error. Example:
                    # * = [
                    #      --help?|context "!help: #fge1"
                    # ]
                    if c != C_PIPE or isoneliner == "": error(S, currentSourcePath)
                    stop = true

            of Delimiter:
                N.delimiter.start = S.i
                N.delimiter.stop = S.i
                N.delimiter.value = $c
                state = EolWsb

            of WsbPrevalue:
                if c notin C_SPACES:
                    let keyword = N.keyword.value notin C_KD_STR
                    if c == C_PIPE and keyword: state = PipeDelimiter
                    elif c == C_COMMA: state = Delimiter
                    else: state = Value
                    rollback(S)

            of Value:
                if N.value.value == "":
                    # Determine value type.
                    if c == C_DOLLARSIGN: `type` = "command-flag"
                    elif c == C_LPAREN:
                        `type` = "list"
                        braces.add(S.i)
                    elif c in C_QUOTES:
                        `type` = "quoted"
                        qchar = c

                    N.value.start = S.i
                    N.value.stop = S.i
                    N.value.value = $c
                else:
                    if c == C_PIPE and N.keyword.value notin C_KD_STR and p != C_ESCAPE:
                        state = PipeDelimiter
                        rollback(S)
                    else:
                        case `type`:
                            of "escaped":
                                if c in C_SPACES and p != C_ESCAPE:
                                    state = EolWsb
                                    forward(S)
                                    continue
                            of "quoted":
                                if c == qchar and p != C_ESCAPE:
                                    state = EolWsb
                                elif c == C_NUMSIGN and qchar == C_NULLB:
                                    comment = true
                                    rollback(S)
                            else: # list|command-flag
                                # The following character after the initial
                                # '$' must be a '('. If it does not follow,
                                # error.
                                #   --help=$"cat ~/files.text"
                                #   --------^ Missing '(' after '$'.
                                if `type` == "command-flag":
                                    if N.value.value.len == 1 and c != C_LPAREN:
                                        error(S, currentSourcePath)

                                # The following logic, is precursor validation
                                # logic that ensures braces are balanced and
                                # detects inline comment.
                                if p != C_ESCAPE:
                                    if c == C_LPAREN and qchar == C_NULLB:
                                        braces.add(S.i)
                                    elif c == C_RPAREN and qchar == C_NULLB:
                                        # If braces len is negative, opening
                                        # braces were never introduced so
                                        # current closing brace is invalid.
                                        if braces.len == 0: error(S, currentSourcePath)
                                        discard braces.pop()
                                        if braces.len == 0: state = EolWsb

                                    if c in C_QUOTES:
                                        if qchar == C_NULLB: qchar = c
                                        elif qchar == c: qchar = C_NULLB

                                    if c == C_NUMSIGN and qchar == C_NULLB:
                                        if braces.len == 0:
                                            comment = true
                                            rollback(S)
                                        else:
                                            S.column = braces.pop() - S.tables.linestarts[S.line]
                                            inc(S.column) # Add 1 to account for 0 base indexing.
                                            error(S, currentSourcePath)

                        N.value.stop = S.i
                        N.value.value &= $c

            of EolWsb:
                if c == C_PIPE and N.keyword.value notin C_KD_STR and p != C_ESCAPE:
                    state = PipeDelimiter
                    rollback(S)
                elif c notin C_SPACES: error(S, currentSourcePath)

            else: discard

        forward(S)

    # If scope is created store ref to Node object.
    if N.value.value == "(":
        N.brackets.start = N.value.start
        N.brackets.stop = N.value.start
        N.brackets.value = N.value.value
        S.scopes.flag = N

    discard validate(S, N)

    if isoneliner == "":
        N.singleton = true

        # Add alias node if it exists.
        if N.alias.value != "":
            var cN = node(nkFlag, S)
            cN.hyphens.value = "-"
            cN.delimiter.value = ","
            cN.name.value = N.alias.value
            cN.singleton = true
            cN.boolean.value = N.boolean.value
            cN.assignment.value = N.assignment.value
            cN.alias.value = cN.name.value
            add(S, cN)

            # Add context node for mutual exclusivity.
            let xN = node(nkFlag, S)
            xN.value.value = "\"{" & N.name.value & "|" & N.alias.value & "}\""
            xN.keyword.value = "context"
            xN.singleton = false
            xN.virtual = true
            xN.args.add(xN.value.value)
            add(S, xN)
        add(S, N)

    return N
