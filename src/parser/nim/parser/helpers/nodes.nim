# Create parsing node object.
#
# @param  {string} type - The object type to create.
# @param  {object} S -State object.
# @return {object} - The created node object.
proc node*(nkType: NodeKind, S: State): Node =
    result = Node(kind: nkType, line: S.line, start: S.i, stop: -1) # new(result)

    # [https://github.com/nim-lang/Nim/issues/11395]
    # [https://forum.nim-lang.org/t/2799#17448]
    case (nkType):

    # Define each Node's props: [https://forum.nim-lang.org/t/4381]
    # [https://nim-lang.org/docs/manual.html#types-reference-and-pointer-types]

    of nkComment:
        result.comment = Branch()

    of nkNewline, nkEmpty: discard

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
