# import std/[os, tables]

# import ../helpers/charsets

import tables, strtabs, sets

type

    Token* = ref object
        kind*, str_rep*, `$`*: string
        line*, `start`*, `end`*, `tid`*: int
        lines*: array[2, int] # Default: [-1, -1]
        list*: bool

# ------------------------------------------------------------------------------

    Flag* = ref object
        tid*: int # -1
        alias*: int # -1
        boolean*: int # -1
        assignment*: int # -1
        multi*: int # -1
        union*: int # -1
        values*: seq[seq[int]]

    # [https://stackoverflow.com/a/63639770]
    LexState* = ref object
        i*, line*, `end`*, start*: int
        kind*: string
        last*, list*: bool
        lines*: array[2, int]
    # LexerData* = tuple[
    #     tokens: seq[Token],
    #     ttypes: StringTableRef,
    #     ttids: seq[int],
    #     dtids: TableRef[string, int],
    #     LINESTARTS: Table[int, int]
    # ]
    LexerData* = tuple
        tokens: seq[Token]
        ttypes: StringTableRef
        ttids: seq[int]
        dtids: TableRef[string, int]
        LINESTARTS: Table[int, int]

    Warning* = tuple[
        filename: string,
        line: int,
        col: int,
        message: string
    ]

    ParseState* = ref object
        tid*: int
        filename*, text*: string
        args*: Args
        ubids*: seq[int]
        excludes*: seq[string]
        # warnings → {line# : [filename, line, col, message]}
        warnings*: TableRef[int, seq[Warning]]
        # warnings*: TableRef[int, seq[
            # tuple[filename: string, line: int, col: int, message: string]
            # ]
        # ] # ?
        # [https://nim-lang.org/docs/tut1.html#advanced-types-sets]
        warn_lines*: HashSet[int]
        warn_lsort*: HashSet[int]
        lexerdata*: LexerData
    Args* = ref object
        action*, source*: string
        trace*, igc*, test*: bool
        fmt*: tuple[`char`: char, amount: int]
        tokens*, branches*: bool


#     # State objects.

#     State* = ref object
#         line*, column*, i*, l*, specf*, last_line_num*: int
#         sol_char*: char
#         text*: string
#         scopes*: Scopes
#         tables*: Tables
#         tests*: seq[string]
#         args*: Args
#     Scopes* = ref object
#         command*, flag*: Node # Track command/flag scopes.
#     Tables* = ref object
#         variables*: Table[string, string]
#         linestarts*: Table[int, int]
#         tree*: Table[string, seq[Node]]
#     Args* = ref object
#         action*, source*: string
#         trace*, igc*, test*: bool
#         fmt*: tuple[`char`: char, amount: int]

#     # Parsing States

#     ParseStates* {.pure.} = enum
#         # Close-Brace
#         Brace, #, EolWsb
#         # Setting
#         Sigil, #[ Name, ]# NameWsb, #, Assignment, ValueWsb, Value, EolWsb
#         # Command
#         Command, ChainWsb, #[ Assignment, Delimiter, ]# GroupOpen,
#         #[ ValueWsb, Value, ]# OpenBracket, #[ EolWsb, ]# OpenBracketWsb,
#         CloseBracket, Oneliner, GroupWsb, GroupCommand, GroupDelimiter,
#         GroupClose,
#         # Flag
#         #[ Value, ]# Hyphen, #[ Name, ]# Keyword, KeywordSpacer, WsbPrevalue,
#         Alias, #[ Assignment, Delimiter, ]# BooleanIndicator, PipeDelimiter,
#         WsbPostname, MultiIndicator, #[ EolWsb ]#
#         # Option
#         Bullet, #[ Value, ]# Spacer, #, WsbPrevalue, EolWsb
#         # Shared States
#         Name, Assignment, Delimiter, Value, ValueWsb, EolWsb

#     # Line Types

#     LineType* {.pure.} = enum
#         LTTerminator LTComment, LTVariable, LTSetting,
#         LTCommand, LTFlag, LTOption, LTCloseBrace, LTSkip

#     # Node + Variants

#     NodeKind* = enum
#         nkEmpty = "EMPTY",
#         nkComment = "COMMENT",
#         nkNewline = "NEWLINE",
#         nkSetting = "SETTING",
#         nkVariable = "VARIABLE",
#         nkCommand = "COMMAND",
#         nkFlag = "FLAG",
#         nkOption = "OPTION",
#         nkBrace = "BRACE"
#     Node* = ref object
#         node*: string
#         line*, start*, stop*: int

#         # Due to Nim's limitations some fields must be shared.
#         # [https://forum.nim-lang.org/t/4817]
#         # [https://github.com/nim-lang/RFCs/issues/19]
#         # [https://forum.nim-lang.org/t/2203]
#         # [https://forum.nim-lang.org/t/3150]
#         # [https://forum.nim-lang.org/t/4233#26335]
#         name*, assignment*, brackets*, value*, delimiter*: Branch
#         args*: seq[string]

#         # Depending on node type add needed fields.
#         case kind*: NodeKind
#         of nkComment:
#             comment*: Branch
#             inline*: bool
#         of nkNewline, nkEmpty: discard
#         of nkSetting, nkVariable: sigil*: Branch
#         of nkCommand:
#             command*: Branch
#             flags*: seq[Node]
#         of nkFlag:
#             hyphens*, variable*, alias*, boolean*, multi*, keyword*: Branch
#             singleton*, virtual*: bool
#         of nkOption: bullet*: Branch
#         of nkBrace: brace*: Branch
#     Branch* = ref object
#         start*, stop*: int
#         value*: string

# # Object constructors.
# include state, nodes
