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
        case kind: NodeKind
        of nkComment:
            comment*: Branch
            inline*: bool
        of nkNewline: discard
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

proc state*(action, cmdname, text, source: string,
            fmt: tuple, trace, igc, test: bool): State =
    new(result)

    var tests: seq[string] = @[]
    var linestarts = initTable[int, int]()
    # Builtin variables.
    var variables = {
        "HOME": os.getEnv("HOME"),
        "OS": hostOS,
        "COMMAND": cmdname,
        "PATH": "~/.nodecliac/registry/" & cmdname,
    }.toTable
    var tree = initTable[string, seq[Node]]()
    tree["nodes"] = @[]

    result.line = 1
    result.column = 1
    result.i = 0
    result.l = text.len
    result.text = text
    result.sol_char = C_NULLB # First non-whitespace char of line.
    result.specf = 0 # Default to allow anything initially.
    result.scopes = Scopes(command: Node(), flag: Node()) #Scopes(command: Node, flag: Node),
    result.tables = Tables(variables: variables, linestarts: linestarts, tree: tree) # Parsing lookup tables.
    result.tests = tests
    # Arguments/parameters for quick access across parsers.
    result.args = Args(action: action, source: source, fmt: fmt, trace: trace, igc: igc, test: test)

proc node*(nkType: NodeKind, S: State): Node =
    result = Node(kind: nkType) # new(result)

    # [https://github.com/nim-lang/Nim/issues/11395]
    # [https://forum.nim-lang.org/t/2799#17448]
    case (nkType):

    # Define each Node's props: [https://forum.nim-lang.org/t/4381]
    # [https://nim-lang.org/docs/manual.html#types-reference-and-pointer-types]

    of nkComment:
        result.comment = Branch()

    of nkNewline: discard

    of nkSetting:
        result.sigil = Branch()
        result.name = Branch()
        result.assignment = Branch()
        result.value = Branch()
        result.args = @[]

    of nkVariable:
        result.sigil = Branch()
        result.name = Branch()
        result.assignment = Branch()
        result.value = Branch()
        result.args = @[]

    of nkCommand:
        result.command = Branch()
        result.name = Branch()
        result.brackets = Branch()
        result.assignment = Branch()
        result.delimiter = Branch()
        result.value = Branch()
        result.flags = @[]

    of nkFlag:
        result.hyphens = Branch()
        result.variable = Branch()
        result.name = Branch()
        result.alias = Branch()
        result.boolean = Branch()
        result.assignment = Branch()
        result.delimiter = Branch()
        result.multi = Branch()
        result.brackets = Branch()
        result.value = Branch()
        result.keyword = Branch()
        result.singleton = false
        result.virtual = false
        result.args = @[]

    of nkOption:
        result.bullet = Branch()
        result.value = Branch()
        result.args = @[]

    of nkBrace:
        result.brace = Branch()

    result.node = $nkType
    result.line = S.line
    result.start = S.i
    result.stop = -1
