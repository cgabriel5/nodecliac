type
    NodeKind = enum
        comment, newline, setting, variable, command, flag, option, brace

    Node* = ref object of RootObj
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

    Branch* = ref object of RootObj
        start*, `end`*: int
        value*: string
