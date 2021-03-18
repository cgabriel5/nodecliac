import std/[os, tables]

import ../helpers/charsets

type

    # State objects.

    State* = ref object
        line*, column*, i*, l*, specf*, last_line_num*: int
        sol_char*: char
        text*: string
        scopes*: Scopes
        tables*: Tables
        tests*: seq[string]
        args*: Args
    Scopes* = ref object
        command*, flag*: Node # Track command/flag scopes.
    Tables* = ref object
        variables*: Table[string, string]
        linestarts*: Table[int, int]
        tree*: Table[string, seq[Node]]
    Args* = ref object
        action*, source*: string
        trace*, igc*, test*: bool
        fmt*: tuple[`char`: char, amount: int]

    # Parsing States

    ParseStates* {.pure.} = enum
        # Close-Brace
        Brace, #, EolWsb
        # Setting
        Sigil, #[ Name, ]# NameWsb, #, Assignment, ValueWsb, Value, EolWsb
        # Command
        Command, ChainWsb, #[ Assignment, Delimiter, ]# GroupOpen,
        #[ ValueWsb, Value, ]# OpenBracket, #[ EolWsb, ]# OpenBracketWsb,
        CloseBracket, Oneliner, GroupWsb, GroupCommand, GroupDelimiter,
        GroupClose,
        # Flag
        #[ Value, ]# Hyphen, #[ Name, ]# Keyword, KeywordSpacer, WsbPrevalue,
        Alias, #[ Assignment, Delimiter, ]# BooleanIndicator, PipeDelimiter,
        WsbPostname, MultiIndicator, #[ EolWsb ]#
        # Option
        Bullet, #[ Value, ]# Spacer, #, WsbPrevalue, EolWsb
        # Shared States
        Name, Assignment, Delimiter, Value, ValueWsb, EolWsb

    # Line Types

    LineType* {.pure.} = enum
        LTTerminator LTComment, LTVariable, LTSetting,
        LTCommand, LTFlag, LTOption, LTCloseBrace, LTSkip

    # Node + Variants

    NodeKind* = enum
        nkEmpty = "EMPTY",
        nkComment = "COMMENT",
        nkNewline = "NEWLINE",
        nkSetting = "SETTING",
        nkVariable = "VARIABLE",
        nkCommand = "COMMAND",
        nkFlag = "FLAG",
        nkOption = "OPTION",
        nkBrace = "BRACE"
    Node* = ref object
        node*: string
        line*, start*, stop*: int

        # Due to Nim's limitations some fields must be shared.
        # [https://forum.nim-lang.org/t/4817]
        # [https://github.com/nim-lang/RFCs/issues/19]
        # [https://forum.nim-lang.org/t/2203]
        # [https://forum.nim-lang.org/t/3150]
        # [https://forum.nim-lang.org/t/4233#26335]
        name*, assignment*, brackets*, value*, delimiter*: Branch
        args*: seq[string]

        # Depending on node type add needed fields.
        case kind*: NodeKind
        of nkComment:
            comment*: Branch
            inline*: bool
        of nkNewline, nkEmpty: discard
        of nkSetting, nkVariable: sigil*: Branch
        of nkCommand:
            command*: Branch
            flags*: seq[Node]
        of nkFlag:
            hyphens*, variable*, alias*, boolean*, multi*, keyword*: Branch
            singleton*, virtual*: bool
        of nkOption: bullet*: Branch
        of nkBrace: brace*: Branch
    Branch* = ref object
        start*, stop*: int
        value*: string

# Object constructors.
include state, nodes
