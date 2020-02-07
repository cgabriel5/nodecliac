import tables
export tables.`$`
include "node-type"

# Loop state objects.
type
    State* = ref object of RootObj
        line*, column*, i*, l*, specf*, last_line_num*: int
        sol_char*, text*: string
        scopes*: Scopes
        tables*: Tables
        args*: Args
    Scopes* = ref object of RootObj
        command*, flag*: ref Node # Track command/flag scopes.
    Tables* = ref object of RootObj
        variables*: Table[string, string]
        linestarts*: Table[int, int]
        tree*: Table[string, Table[string, seq[Node]]]
    Args* = ref object of RootObj
        action*, source*, fmt*: string
        trace*, igc*, test*: bool

proc state*(action: string, text: string, source: string, fmt: tuple,
    trace: bool, igc: bool, test: bool): State =

    var linestarts = initTable[int, int]()
    var variables = initTable[string, string]()
    var tree = initTable[string, Table[string, seq[Node]]]()

    return State(
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
