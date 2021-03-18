import std/[strformat, strutils, tables, re]

import ../helpers/[types, charsets]

# Formats (prettifies) .acmap file.
#
# @param  {object} S - State object.
# @return {string} - The prettied file contents.
proc formatter*(S: State): tuple =
    let igc = S.args.igc
    var nodes = S.tables.tree["nodes"]
    let eN = Node()
    var output: seq[string] = @[]
    var passed: seq[Node] = @[]
    let r = re"^[ \t]+"
    var alias: Node

    # Indentation level multipliers.
    const MXP = {
        "COMMENT": 0,
        "COMMAND": 0,
        "FLAG": 1,
        "OPTION": 2,
        "BRACE": 0,
        "NEWLINE": 0,
        "SETTING": 0,
        "VARIABLE": 0
    }.toTable

    var nl_count = 0 # Track consecutive newlines.
    var scopes: seq[int] = @[] # Track command/flag scopes.

    let (ichar, iamount) = S.args.fmt
    proc indent(`type`: string = "COMMENT", count: int = 0): string =
        let level = if count > 0: count else: MXP[`type`]
        result = ichar.repeat(level * iamount)

    # Gets next node that is not a comment. Also takes into account
    #     subsequent newline node.
    #
    # @param  {number} i - The index to start search.
    # @param  {number} l - The length of array.
    # @return {object} - The node object.
    proc nextnode(i, l: int): Node =
        result = eN
        if igc:
            var i = i + 1
            while i < l:
                let N = nodes[i]
                let t = N.kind
                if t != nkComment:
                    result = N
                    break
                elif t == nkComment:
                    inc(i)
                inc(i)
        else: result = if i + 1 < l: nodes[i + 1] else: eN

    # Gets the node previously iterated over.
    #
    # @param  {number} i - The index to start search.
    # @param  {number} l - The length of array.
    # @return {object} - The node object.
    proc lastnode(i, l: int): Node =
        result = eN
        if igc: result = passed[passed.high]
        else: result = if i - 1 < l: nodes[i - 1] else: eN

    # Loop over nodes to build formatted file.

    var i = 0
    let l = nodes.len
    while i < l:
        let N = nodes[i]
        let t = N.kind

        # Ignore starting newlines.
        if output.len == 0 and t == nkNewline:
            inc(i)
            continue
        # Remove comments when flag is provided.
        if igc and t == nkComment:
            inc(i) # + 1 to skip next newline node.
            inc(i) # + 1 to account for continue.
            continue

        case (t):
            of nkComment:
                let scope = if scopes.len > 0: scopes[^1] else: 0
                let pad = if not N.inline: indent(count = scope) else: " "

                output.add(fmt"{pad}{N.comment.value}")

            of nkNewline:
                let nN = nextnode(i, l);

                if nl_count <= 1: output.add("\n")
                inc(nl_count)
                if nN.kind != nkNewline: nl_count = 0

                if scopes.len != 0:
                    let last = output[output.len - 2]
                    let lchar = last[last.len - 1]
                    let isbrace = lchar == C_LBRACKET or lchar == C_LPAREN
                    if isbrace and nN.kind == nkNewline: inc(nl_count)
                    if nN.kind == nkBrace:
                        if lastnode(i, l).kind == nkNewline: discard output.pop()

            of nkSetting:
                let nval = N.name.value
                let aval = N.assignment.value
                let vval = N.value.value

                var r = "@"
                if nval != "":
                    r &= nval
                    if aval != "":
                        r &= fmt" {aval}"
                        if vval != "":
                            r &= fmt" {vval}"

                output.add(r)

            of nkVariable:
                let nval = N.name.value
                let aval = N.assignment.value
                let vval = N.value.value

                var r = "$"
                if nval != "":
                    r &= nval
                    if aval != "":
                        r &= fmt" {aval}"
                        if vval != "":
                            r &= fmt" {vval}"

                output.add(r)

            of nkCommand:
                let vval = N.value.value
                let cval = N.command.value
                let dval = N.delimiter.value
                let aval = N.assignment.value

                var r = ""
                if cval != "":
                    r &= cval
                    if dval != "":
                        r &= dval
                    else:
                        if aval != "":
                            r &= fmt" {aval}"
                            if vval != "":
                                r &= fmt" {vval}"

                let nN = nextnode(i, l)
                if nN.kind == nkFlag: r &= " "
                output.add(r)
                if vval != "" and vval == "[": scopes.add(1) # Track scope.

            of nkFlag:
                if N.virtual:
                    inc(i) # + 1 to account for continue.
                    continue

                let kval = N.keyword.value
                let hval = N.hyphens.value
                let nval = N.name.value
                let bval = N.boolean.value
                let aval = N.assignment.value
                let dval = N.delimiter.value
                let mval = N.multi.value
                let vval = N.value.value
                let ival = N.alias.value
                let singleton = N.singleton
                let pad = indent(count = singleton.int)
                var pipe_del = if singleton: "" else: "|"

                # Skip if an alias and set ref for later.
                if ival != "" and ival == nval:
                    alias = N
                    inc(i) # + 1 to account for continue.
                    continue

                # Note: If nN is a flag reset var.
                if pipe_del != "":
                    let nN = nextnode(i, l)
                    if nN.kind != nkFlag: pipe_del = ""

                var r = pad

                if kval != "":
                    r &= kval
                    if vval != "": r &= fmt" {vval}"
                else:
                    if hval != "":
                        r &= hval
                        if nval != "":
                            r &= nval
                            if ival != "" and alias != nil and ival == alias.alias.value:
                                r &= "::" & ival
                                alias = nil
                            if bval != "":
                                r &= bval
                            elif aval != "":
                                r &= aval
                                if mval != "": r &= mval
                                if dval != "": r &= dval
                                if vval != "": r &= vval

                output.add(r & pipe_del)

                if vval != "" and vval == "(": scopes.add(2) # Track scope.

            of nkOption:
                let bval = N.bullet.value
                let vval = N.value.value
                let pad = indent("OPTION")

                var r = pad
                if bval != "":
                    r &= bval
                    if vval != "":
                        r &= fmt" {vval}"

                output.add(r)

            of nkBrace:
                let bval = N.brace.value
                var pad = indent(count = if bval == "]": 0 else: 1)

                if bval == ")":
                    let l = output.len
                    let last = output[l - 1]
                    let slast = output[l - 2]
                    let ll = last.len
                    let lfchar = last.replace(r, "")[0]
                    let slchar = slast[slast.len - 1]

                    if lfchar == C_HYPHEN and last[ll - 1] == C_LPAREN: pad = ""
                    elif last == "\n" and slchar == C_LPAREN:
                        pad = ""
                        discard output.pop()
                elif bval == "]":
                    let l = output.len
                    let last = output[l - 1]
                    let slast = output[l - 2]
                    if last == "\n" and slast == "\n":
                        discard output.pop()
                    else:
                        let sl = slast.len
                        let slchar = slast[sl - 1]
                        if last == "\n" and slchar == C_LBRACKET: discard output.pop()

                output.add(fmt"{pad}{bval}")
                if scopes.len > 0: discard scopes.pop() # Un-track last scope.

            else: discard

        passed.add(N)
        inc(i)

    i = output.high
    while true:
        if output[i] != "\n": break
        discard output.pop()
        dec(i)

    var data: tuple[
        acdef: string,
        config: string,
        keywords: string,
        filedirs: string,
        contexts: string,
        formatted: string,
        placeholders: StringTableRef,
        tests: string
    ]
    data.formatted = output.join("") & "\n"
    result = data
