# State object.
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
