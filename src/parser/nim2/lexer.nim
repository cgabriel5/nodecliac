import ./helpers/[types]
# import ./utils/types as t

import tables, re, strtabs, strutils, sets

const
    C_NL = '\n'
    C_DOT = '.'
    C_TAB = '\t'
    C_PIPE = '|'
    C_SPACE = ' '
    C_QMARK = '?'
    C_HYPHEN = '-'
    C_ESCAPE = '\\'
    C_LPAREN = '('
    C_RPAREN = ')'
    C_LCURLY = '{'
    C_RCURLY = '}'
    C_LBRACE = '['
    C_RBRACE = ']'
    C_ATSIGN = '@'
    C_ASTERISK = '*'
    C_DOLLARSIGN = '$'
    C_UNDERSCORE = '_'

const SOT = {
    # Start-of-token chars.
    "#": "tkCMT",
    "@": "tkSTN",
    "$": "tkVAR",
    "-": "tkFLG",
    "?": "tkQMK",
    "*": "tkMTL",
    ".": "tkDDOT",
    "\"": "tkSTR",
    "'": "tkSTR",
    "=": "tkASG",
    "|": "tkDPPE",
    ",": "tkDCMA",
    ":": "tkDCLN",
    ";": "tkTRM",
    "(": "tkBRC",
    ")": "tkBRC",
    "[": "tkBRC",
    "]": "tkBRC",
    "{": "tkBRC",
    "}": "tkBRC",
    "\n": "tkNL"
}.toTable

const BRCTOKENS = {
  C_LPAREN: "tkBRC_LP",
  C_RPAREN: "tkBRC_RP",
  C_LCURLY: "tkBRC_LC",
  C_RCURLY: "tkBRC_RC",
  C_LBRACE: "tkBRC_LB",
  C_RBRACE: "tkBRC_RB"
}.toTable

var LINESTARTS = { 1: -1 }.toTable

const KEYWORDS = ["default", "context", "filedir", "exclude"]
# Invalid command start-of-token chars.
const XCSCOPES = { C_ATSIGN, C_DOT, C_LCURLY, C_RCURLY }

# [https://stackoverflow.com/a/12333839]
# [https://www.geeksforgeeks.org/set-in-cpp-stl/]
# const SPACES = toHashSet([C_SPACE, C_TAB])
const TkCMD_TK_TYPES = toHashSet([C_HYPHEN, C_ESCAPE])
const TkTBD_TK_TYPES = toHashSet([
  C_SPACE,
  C_TAB,
  C_DOLLARSIGN,
  C_ATSIGN,
  C_PIPE,
  C_LCURLY,
  C_RCURLY,
  C_LBRACE,
  C_RBRACE,
  C_LPAREN,
  C_RPAREN,
  C_HYPHEN,
  C_QMARK,
  C_ASTERISK
])
const TkTBD_TK_TYPES2 = toHashSet([C_NL, C_SPACE, C_TAB])
const TkEOP_TK_TYPES = toHashSet([$C_SPACE, $C_TAB, $C_NL])
const TkTYPES_RESET1 = toHashSet(["tkCMD", "tkTBD"])
const TkTYPES_RESET2 = toHashSet(["tkCMD", "tkFLG", "tkSTN", "tkVAR"])
const TkTYPES_RESET3 = toHashSet(["tkSTN", "tkVAR"])
const TkTYPES_RESET4 = toHashSet(["tkCMT", "tkNL", "tkEOP"])

# [https://stackoverflow.com/a/31280947]
# [https://dev.to/tillsanders/let-s-stop-using-a-za-z-4a0m]
# [http://www.regular-expressions.info/unicode.html#category]
# [http://www.regular-expressions.info/xregexp.html]
# [http://www.regular-expressions.info/posixbrackets.html]
# [https://ruby-doc.org/core-1.9.3/Regexp.html]
#
# [https://stackoverflow.com/a/64030026]
# [https://github.com/nitely/nim-normalize]
proc isalnum(s: string): bool =
  if s == "": return false
  return contains(s, re("^[\\p{L}\\p{Nl}\\p{Nd}]+$"))

  # echo (isalnum("anc")    # true
  # echo (isalnum("anc12")  # true
  # echo (isalnum("anc12#") # false
  # echo (isalnum("")       # false

proc isalpha(s: string): bool =
  if s == "": return false
  return contains(s, re("^[\\p{L}\\p{Nl}]+$"))

  # echo (isalpha("abc")   # true
  # echo (isalpha("ab123") # false
  # echo (isalpha("")      # false

# proc lastn(list: seq[string], int offset = -1): int =
proc lastn(list: openarray[int|Token], offset: int = -1): int|Token =
    return list[list.len + offset]
proc strfrmpts(s: string, start, `end`: int): string =
    return s[start .. `end`]

# Helper functions --------------------------------------------------------START

# Checks state object kind matches provided kind.
proc kind(S: LexState, k: string): bool =
    return S.kind == k

# Helper functions ----------------------------------------------------------END

proc tokenizer*(text: string): tuple =
    # var c = ""
    var dtids = newTable[string, int]()
    var ttids: seq[int] = @[]
    var tokens: seq[Token] = @[]
    var ttypes = newStringTable()
    var token_count = 0
    var l = text.len
    var cmdscope = false
    var valuelist = false # Value list
    var brcparens: seq[int] = @[]
    # [https://nim-by-example.github.io/types/objects/]
    var S = LexState(i: 0, line: 1, kind: "", `end`: -1, start: -1)

    # Adds the token to tokens array.
    proc add_token(S: LexState, text: string) =
        if ttids.len > 0 and tokens.len > 0:
            let prevtk = tokens[lastn(ttids)]

            # Keyword reset.
            if kind(S, "tkSTR") and (prevtk.kind == "tkCMD" or (cmdscope and prevtk.kind == "tkTBD")):
                if strfrmpts(text, prevtk.start, prevtk.`end`) in KEYWORDS:
                    prevtk.kind = "tkKYW"

              # Reset: default $("cmd-string")
            elif (
                kind(S, "tkVAR") and
                S.`end` - S.start == 0 and
                (prevtk.kind == "tkCMD" or (cmdscope and prevtk.kind == "tkTBD"))
            ):
                if strfrmpts(text, prevtk.start, prevtk.`end`) == "default":
                    prevtk.kind = "tkKYW"

            elif valuelist and S.kind == "tkFLG" and S.start == S.`end`:
                S.kind = "tkFOPT" # Hyphen.

                # When parsing a value list '--flag=()', that is not a
                # string/command-string should be considered a value.
            elif valuelist and S.kind in TkTYPES_RESET1:
                S.kind = "tkFVAL"

            # 'Merge' tkTBD tokens if possible.
            elif (
                kind(S, "tkTBD") and
                prevtk.kind == "tkTBD" and
                prevtk.line == S.line and
                S.start - prevtk.`end` == 1
            ):
                prevtk.`end` = S.`end`
                S.kind = ""
                return

            elif kind(S, "tkCMD") or kind(S, "tkTBD"):
                # Reverse loop to get find first command/flag tokens.
                var lastpassed = ""
                # [https://stackoverflow.com/a/19887835]
                var i = token_count - 1
                while i > -1:
                    let lkind = ttypes[$i]
                    if lkind in TkTYPES_RESET2:
                        lastpassed = lkind
                        break
                    dec(i)

                # Handle: 'program = --flag::f=123'
                if (prevtk.kind == "tkASG" and prevtk.line == S.line and
                    lastpassed == "tkFLG"):
                    S.kind = "tkFVAL"

                if S.kind != "tkFVAL" and ttids.len > 1:
                    let prevtk2 = tokens[lastn(ttids, -2)].kind

                    # Flag alias '::' reset.
                    if prevtk.kind == "tkDCLN" and prevtk2 == "tkDCLN":
                        S.kind = "tkFLGA"

                    # Setting/variable value reset.
                    if prevtk.kind == "tkASG" and prevtk2 in TkTYPES_RESET3:
                        S.kind = "tkAVAL"

        # Reset when single '$'.
        if kind(S, "tkVAR") and S.`end` - S.start == 0:
            S.kind = "tkDLS"

        # If a brace token, reset kind to brace type.
        if kind(S, "tkBRC"):
            S.kind = BRCTOKENS[text[S.start]]

        # Universal command multi-char reset.
        if kind(S, "tkMTL") and (tokens.len == 0 or lastn(tokens).kind != "tkASG"):
            S.kind = "tkCMD"

        ttypes[$token_count] = S.kind
        if S.kind notin TkTYPES_RESET4:
            # Track token ids to help with parsing.
            dtids[$token_count] = (if token_count > 0 and ttids.len > 0: lastn(ttids) else: 0)
            ttids.add(token_count)

        var copy = Token(
            kind: S.kind,
            line: S.line,
            start: S.start,
            `end`: S.`end`,
            lines: S.lines,
            tid: token_count,
            list: S.list
        )

        if S.last:
            S.last = false
        tokens.add(copy)

        S.kind = ""

        if S.lines[0] != -1: S.lines = [-1, -1]
        if S.list: S.list = false

        token_count += 1

    # Checks if token is at needed char index.
    proc charpos(S: LexState, pos: int): bool =
        return S.i - S.start == pos - 1

    # # Checks state object kind matches provided kind.
    # proc kind(S: LexState, k: string): bool =
    #     return S.kind == k

    # Forward loop x amount.
    proc forward(S: LexState, amount: int) {.noSideEffect.} =
        S.i += amount

    # Rollback loop x amount.
    proc rollback(S: LexState, amount: int) {.noSideEffect.} =
        S.i -= amount

    # Get previous iteration char.
    proc prevchar(S: LexState, text: string): char =
        return text[S.i - 1]

    proc tk_eop(S: LexState, c: string, text: string) =
        # Determine in parser.
        S.kind = "tkEOP"
        S.`end` = S.i
        if c in TkEOP_TK_TYPES:
            S.`end` -= 1
        add_token(S, text)

    # var c, n: char
    var c: char
    while S.i < l:
        c = text[S.i]

        # Add 'last' key on last iteration.
        if S.i == l - 1:
            S.last = true

        if S.kind == "":
            if c in { C_SPACE, C_TAB }:
                forward(S, 1)
                continue

            if c == C_NL:
                S.line += 1
                LINESTARTS[S.line] = S.i

            S.start = S.i
            S.kind = SOT.getOrDefault($c, "tkTBD")
            if S.kind == "tkTBD":
                if (not cmdscope and isalnum($c)) or
                    (cmdscope and c in XCSCOPES and isalpha($c)):
                        S.kind = "tkCMD"

        case (S.kind):
            of "tkSTN":
                if S.i - S.start > 0 and not isalnum($c):
                    rollback(S, 1)
                    S.`end` = S.i
                    add_token(S, text)

            of "tkVAR":
                if (S.i - S.start > 0 and not (isalnum($c) or c == C_UNDERSCORE)):
                    rollback(S, 1)
                    S.`end` = S.i
                    add_token(S, text)

            of "tkFLG":
                if S.i - S.start > 0 and not (isalnum($c) or c == C_HYPHEN):
                    rollback(S, 1)
                    S.`end` = S.i
                    add_token(S, text)

            of "tkCMD":
                if not (isalnum($c) or (c in TkCMD_TK_TYPES) or prevchar(S, text) == C_ESCAPE):
                    # Allow escaped chars.
                    rollback(S, 1)
                    S.`end` = S.i
                    add_token(S, text)

            of "tkCMT":
                if c == C_NL:
                    rollback(S, 1)
                    S.`end` = S.i
                    add_token(S, text)

            of "tkSTR":
                # Store initial line where string starts.
                # [https://stackoverflow.com/a/18358357]
                # if not S.lines:
                if S.lines == [-1, -1]:
                    S.lines = [S.line, -1]

                # Account for '\n's in string to track where string ends
                if c == C_NL:
                    S.line += 1
                    LINESTARTS[S.line] = S.i

                if (not charpos(S, 1) and c == text[S.start] and prevchar(S, text) != C_ESCAPE):
                    S.`end` = S.i
                    S.lines[1] = S.line
                    add_token(S, text)

            of "tkTBD":
                S.`end` = S.i
                if c == C_NL or (c in TkTBD_TK_TYPES and prevchar(S, text) != C_ESCAPE):
                # if c == C_NL || (TkTBD_TK_TYPES.has(c) && prevchar(S, text) != C_ESCAPE):
                    if not (c in TkTBD_TK_TYPES2):
                        rollback(S, 1)
                        S.`end` = S.i
                    else:
                        # Let '\n' pass through to increment line count.
                        if c == C_NL:
                            rollback(S, 1)
                        S.`end` -= 1
                    add_token(S, text)

            of "tkBRC":
                if c == C_LPAREN:
                    if tokens[lastn(ttids)].kind != "tkDLS":
                        valuelist = true
                        brcparens.add(0) # Value list.
                        S.list = true
                    else:
                        brcparens.add(1);
                    # Command-string.
                elif c == C_RPAREN:
                    if brcparens.pop() == 0:
                        valuelist = false
                        S.list = true
                elif c == C_LBRACE:
                    cmdscope = true
                elif c == C_RBRACE:
                    cmdscope = false
                S.`end` = S.i
                add_token(S, text)

            else:
                # tkDEF
                S.`end` = S.i;
                add_token(S, text);

        # Run on last iteration.
        if S.last:
            tk_eop(S, $c, text)

        forward(S, 1)

    # To avoid post parsing checks, add a special end-of-parsing token.
    S.kind = "tkEOP"
    S.start = -1
    S.`end` = -1
    add_token(S, text)

    var data: LexerData
    data.tokens = tokens
    data.ttypes = ttypes
    data.ttids = ttids
    data.dtids = dtids
    data.LINESTARTS = LINESTARTS

    result = data
