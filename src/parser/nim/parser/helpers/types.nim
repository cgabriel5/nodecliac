from os import getEnv
from tables import Table, toTable, initTable, `[]=`, `$`

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

    # Node + Variants

    NodeKind* = enum
        comment, newline, setting, variable, command, flag, option, brace
    Node* = ref object
        node*: string
        line*, start*, `end`*: int

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
        of comment: comment*: Branch
        of newline: discard
        of setting, variable: sigil*: Branch
        of command:
            command*: Branch
            flags*: seq[Node]
        of flag:
            hyphens*, variable*, alias*, boolean*, multi*, keyword*: Branch
            singleton*: bool
        of option: bullet*: Branch
        of brace: brace*: Branch
    Branch* = ref object
        start*, `end`*: int
        value*: string

# Object constructors.

proc state*(action: string, cmdname: string, text: string, source: string,
    fmt: tuple, trace: bool, igc: bool, test: bool): State =
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
    result.sol_char = '\0' # First non-whitespace char of line.
    result.specf = 0 # Default to allow anything initially.
    result.scopes = Scopes(command: Node(), flag: Node()) #Scopes(command: Node, flag: Node),
    result.tables = Tables(variables: variables, linestarts: linestarts, tree: tree) # Parsing lookup tables.
    result.tests = tests
    # Arguments/parameters for quick access across parsers.
    result.args = Args(action: action, source: source, fmt: fmt, trace: trace, igc: igc, test: test)

proc node*(S: State, node: string): Node =
    new(result)

    # [https://github.com/nim-lang/Nim/issues/11395]
    # [https://forum.nim-lang.org/t/2799#17448]
    case (node):

    # Define each Node's props: [https://forum.nim-lang.org/t/4381]
    # [https://nim-lang.org/docs/manual.html#types-reference-and-pointer-types]

    of "COMMENT":
        result = Node(kind: comment)
        result.comment = Branch()

    of "NEWLINE": result = Node(kind: newline)

    of "SETTING":
        result = Node(kind: setting)
        result.sigil = Branch()
        result.name = Branch()
        result.assignment = Branch()
        result.value = Branch()
        result.args = @[]

    of "VARIABLE":
        result = Node(kind: variable)
        result.sigil = Branch()
        result.name = Branch()
        result.assignment = Branch()
        result.value = Branch()
        result.args = @[]

    of "COMMAND":
        result = Node(kind: command)
        result.command = Branch()
        result.name = Branch()
        result.brackets = Branch()
        result.assignment = Branch()
        result.delimiter = Branch()
        result.value = Branch()
        result.flags = @[]

    of "FLAG":
        result = Node(kind: flag)
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
        result.args = @[]

    of "OPTION":
        result = Node(kind: option)
        result.bullet = Branch()
        result.value = Branch()
        result.args = @[]

    of "BRACE":
        result = Node(kind: brace)
        result.brace = Branch()

    result.node = node
    result.line = S.line
    result.start = S.i
    result.`end` = -1
