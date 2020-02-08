from tables import Table, initTable, `[]=`, `$`

type

    # State objects.

    State* = object of RootObj
        line*, column*, i*, l*, specf*, last_line_num*: int
        sol_char*, text*: string
        scopes*: Scopes
        tables*: Tables
        args*: Args
    Scopes* = object of RootObj
        command*, flag*: Node # Track command/flag scopes.
    Tables* = object of RootObj
        variables*: Table[string, string]
        linestarts*: Table[int, int]
        # tree*: Table[string, Table[string, seq[Node]]]
        tree*: Table[string, seq[Node]]
    Args* = object of RootObj
        action*, source*, fmt*: string
        trace*, igc*, test*: bool

    # Node + Variants

    NodeKind* = enum
        comment, newline, setting, variable, command, flag, option, brace
    Node* = object of RootObj
        node*: string
        line*, start*, `end`*: int

        # Due to Nim's limitations some fields must be shared.
        # [https://forum.nim-lang.org/t/4817]
        # [https://github.com/nim-lang/RFCs/issues/19]
        # [https://forum.nim-lang.org/t/2203]
        # [https://forum.nim-lang.org/t/3150]
        # [https://forum.nim-lang.org/t/4233#26335]
        name*, assignment*, brackets*, value*: Branch
        args*: seq[Node]

        # Depending on node type add needed fields.
        case kind: NodeKind
        of comment: comment*: Branch
        of newline: discard
        of setting, variable: sigil*: Branch
        of command:
            command*, delimiter*: Branch
            flags*: seq[Node]
        of flag:
            hyphens*, variable*, boolean*, multi*, keyword*: Branch
            singleton*: bool
        of option: bullet*: Branch
        of brace: brace*: Branch
    Branch* = object of RootObj
        start*, `end`*: int
        value*: string

# Object constructors.

proc state*(action: string, text: string, source: string, fmt: tuple,
    trace: bool, igc: bool, test: bool): State =

    var linestarts = initTable[int, int]()
    var variables = initTable[string, string]()
    var tree = initTable[string, seq[Node]]()
    tree["nodes"] = @[]

    result = State(
        line: 1,
        column: 0,
        i: 0,
        l: text.len,
        text: text,
        sol_char: "", # First non-whitespace char of line.
        specf: 0, # Default to allow anything initially.
        scopes: Scopes(), #Scopes(command: Node, flag: Node),
        tables: Tables(variables: variables, linestarts: linestarts, tree: tree), # Parsing lookup tables.
        # Arguments/parameters for quick access across parsers.
        args: Args(action: action)
    )

proc node*(S: State, node: string): Node =
    # [https://github.com/nim-lang/Nim/issues/11395]
    # [https://forum.nim-lang.org/t/2799#17448]
    case (node):
    of "COMMENT": result = Node(kind: comment)
    of "NEWLINE": result = Node(kind: newline)
    of "SETTING": result = Node(kind: setting)
    of "VARIABLE": result = Node(kind: variable)
    of "COMMAND": result = Node(kind: command)
    of "FLAG": result = Node(kind: flag)
    of "OPTION": result = Node(kind: option)
    of "BRACE": result = Node(kind: brace)

    result.node = node
    result.line = S.line
    result.start = S.i
    result.end = -1
