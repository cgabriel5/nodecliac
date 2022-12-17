# [https://csvjson.com/csv2json]

import std/[tables, strutils, strformat, sequtils, nre, json, os, enumerate]

import ../helpers/[types]
import ../utils/[chalk, exit, fs]
import ../utils/types as t

const CSV_DELIMITER = ';'
const TB_LABELS = ["tid", "kind", "line", "column", "start", "end", "lines", "$", "list", "value"]
let R = re"[\r\n]|\t"
let R_semicolon = re";"

proc collens(tokens: seq[Token], tbdb_lens: var Table[string, int],
    LINESTARTS: Table[int, int]) =
    # Loop over each token and check each property length. Update the table
    # with the largest string property length.
    for token in tokens:
        let
            tid = token.tid
            kind = token.kind
            # line = token.line
            # [TODO]: When the token is a string it can span multiple lines
            # so get the start line instead of the token:line entry. However,
            # look into the ending string line is the value in the token object.
            line = (if token.lines[0] notin [0, -1]: token.lines[0] else: token.line)
            start = token.start
            lines = (if token.lines[0] == 0: [-1, -1] else: token.lines)
            `end` = token.`end`
            str = token.`$`
            list = token.list

        let tid_len = ($tid).len
        let kind_len = kind.len
        let line_len = ($line).len
        let start_len = ($start).len
        let end_len = ($`end`).len
        var lines_len = 0
        if lines != [-1, -1]:
            # Get the lengths of each number and add 1 for the comma.
            lines_len = ($lines[0]).len + ($lines[1]).len + 1
        let str_len = str.len
        let list_len = (if list: 4 else: 0)

        let line_col = ($(start - LINESTARTS[line])).len

        if tid_len > tbdb_lens["tid"]: tbdb_lens["tid"] = tid_len
        if kind_len > tbdb_lens["kind"]: tbdb_lens["kind"] = kind_len
        if line_len > tbdb_lens["line"]: tbdb_lens["line"] = line_len
        if start_len > tbdb_lens["start"]: tbdb_lens["start"] = start_len
        if end_len > tbdb_lens["end"]: tbdb_lens["end"] = end_len
        if lines_len > tbdb_lens["lines"]: tbdb_lens["lines"] = lines_len
        if str_len > tbdb_lens["$"]: tbdb_lens["$"] = str_len
        if list_len > tbdb_lens["list"]: tbdb_lens["list"] = list_len
        if `end` - start + 1 > tbdb_lens["value"]: tbdb_lens["value"] = `end` - start + 1

        if line_col > tbdb_lens["column"]: tbdb_lens["column"] = line_col

# module.exports = async (branches, cchains, flags, settings, S, cmdname) => {
# module.exports = async (S, branches) => {
# module.exports = async (tokens, text) => {
proc tables(tokens: seq[Token], text: string,
    tbdb_lens: var Table[string, int], `type`: string,
    LINESTARTS: Table[int, int], bid: var int = 0): array[3, string] =
    # let tokens = S.lexerdata.tokens

    const TB_TOP_LEFT_CORNER = "┌"
    const TB_TOP_RIGHT_CORNER = "┐"
    const TB_BOTTOM_LEFT_CORNER = "└"
    const TB_BOTTOM_RIGHT_CORNER = "┘"
    const TB_MIDDLE_T_TOP = "┬"
    const TB_MIDDLE_T_BOTTOM = "┴"
    const TB_MIDDLE_PIPE = "│"
    const TB_MIDDLE_STRAIGHT = "─"
    const TB_MIDDLE_CROSS = "┼"
    const TB_MIDDLE_T_LEFT = "├"
    const TB_MIDDLE_T_RIGHT = "┤"

    var rows: seq[string] = @[]
    var output: seq[string] = @[]

    # // Populate table with label keys with labels and their respective lengths.
    # for (let i = 0, l = TB_LABELS.len; i < l; i++) {
    #   let label = TB_LABELS[i]
    #   tbdb_lens[label] = label.len
    # }

    # Loop over each token and check each property length. Update the table
    # with the largest string property length.
    for token in tokens:
        let
            tid = token.tid
            kind = token.kind
            # line = token.line
            # [TODO]: When the token is a string it can span multiple lines
            # so get the start line instead of the token:line entry. However,
            # look into the ending string line is the value in the token object.
            line = (if token.lines[0] notin [0, -1]: token.lines[0] else: token.line)
            start = token.start
            lines = (if token.lines[0] == 0: [-1, -1] else: token.lines)
            `end` = token.`end`
            str = token.`$`
            list = token.list

        let tid_len = ($tid).len
        let kind_len = kind.len
        let line_len = ($line).len
        let start_len = ($start).len
        let end_len = ($`end`).len
        var lines_len = 0
        if lines != [-1, -1]:
            # Get the lengths of each number and add 1 for the comma.
            lines_len = ($lines[0]).len + ($lines[1]).len + 1
        let str_len = str.len
        let list_len = (if list: 4 else: 0)

        let line_col = ($(start - LINESTARTS[line])).len

        if tid_len > tbdb_lens["tid"]: tbdb_lens["tid"] = tid_len
        if kind_len > tbdb_lens["kind"]: tbdb_lens["kind"] = kind_len
        if line_len > tbdb_lens["line"]: tbdb_lens["line"] = line_len
        if start_len > tbdb_lens["start"]: tbdb_lens["start"] = start_len
        if end_len > tbdb_lens["end"]: tbdb_lens["end"] = end_len
        if lines_len > tbdb_lens["lines"]: tbdb_lens["lines"] = lines_len
        if str_len > tbdb_lens["$"]: tbdb_lens["$"] = str_len
        if list_len > tbdb_lens["list"]: tbdb_lens["list"] = list_len
        if `end` - start + 1 > tbdb_lens["value"]: tbdb_lens["value"] = `end` - start + 1

        if line_col > tbdb_lens["column"]: tbdb_lens["column"] = line_col

    var rowcap: seq[string] = @[]
    var rowlabels: seq[string] = @[]
    var rowtail: seq[string] = @[]

    var header_0 = (if `type` == "branches": "Branch" else: "Tokens")
    if `type` == "branches": inc(bid)
    elif `type` == "tokens": bid = tokens.len
    rowcap.add(fmt" {TB_TOP_LEFT_CORNER}{TB_MIDDLE_STRAIGHT} " & header_0.chalk("bold") & fmt" {TB_MIDDLE_STRAIGHT} " & ($bid).chalk("bold", "magenta") & fmt" {TB_MIDDLE_STRAIGHT}{TB_TOP_RIGHT_CORNER}" & "\n")

    # Generate the top row/layer of the table.
    let l = TB_LABELS.len
    for i, label in TB_LABELS:
        if i == 0: # first label
            rowcap.add(TB_TOP_LEFT_CORNER)
            rowcap.add(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
        elif l - 1 == i: # last label
            rowcap.add(TB_MIDDLE_T_TOP)
            rowcap.add(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
            rowcap.add(TB_TOP_RIGHT_CORNER)
        else:
            rowcap.add(TB_MIDDLE_T_TOP)
            rowcap.add(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))

        #////////

        # Generate the labels row of the table.
        var nlabel = " " & label.chalk("bold") & " ".repeat(abs(tbdb_lens[label] - label.len) + 1)
        if i == 0: # first label
            rowlabels.add(TB_MIDDLE_PIPE)
            rowlabels.add(nlabel)
        elif l - 1 == i: # last label
            rowlabels.add(TB_MIDDLE_PIPE)
            rowlabels.add(nlabel)
            rowlabels.add(TB_MIDDLE_PIPE)
        else:
            rowlabels.add(TB_MIDDLE_PIPE)
            rowlabels.add(nlabel)

        #////////

        # Generate tail end of the table.
        if tokens.len == 1:
            if i == 0: # first label
                rowtail.add(TB_BOTTOM_LEFT_CORNER)
                rowtail.add(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
            elif l - 1 == i: # last label
                rowtail.add(TB_MIDDLE_T_BOTTOM)
                rowtail.add(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
                rowtail.add(TB_BOTTOM_RIGHT_CORNER)
            else:
                rowtail.add(TB_MIDDLE_T_BOTTOM)
                rowtail.add(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
        else: # Empty file (no tokens).
            if i == 0: # first label
                rowtail.add(TB_MIDDLE_T_LEFT)
                rowtail.add(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
            elif l - 1 == i: # last label
                rowtail.add(TB_MIDDLE_CROSS)
                rowtail.add(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
                rowtail.add(TB_MIDDLE_T_RIGHT)
            else:
              rowtail.add(TB_MIDDLE_CROSS)
              rowtail.add(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))

    # var header = concat(rowcap, @["\n"], rowlabels, @["\n"], rowtail).join("")
    var header = concat(rowcap, @["\n"], rowlabels).join("")

    # Generate table separator.
    var separator_parts: seq[string] = @[]
    for i, label in TB_LABELS:
        if i == 0: # first label
            separator_parts.add(TB_MIDDLE_T_LEFT)
            separator_parts.add(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
        elif l - 1 == i: # last label
            separator_parts.add(TB_MIDDLE_CROSS)
            separator_parts.add(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
            separator_parts.add(TB_MIDDLE_T_RIGHT)
        else:
            separator_parts.add(TB_MIDDLE_CROSS)
            separator_parts.add(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
    let separator = separator_parts.join("")

    # output.add("\n")
    for x, token in tokens:
        output.add("\n")

        var row: seq[string] = @[]

        let
            tid = token.tid
            kind = token.kind
            # line = token.line
            # [TODO]: When the token is a string it can span multiple lines
            # so get the start line instead of the token:line entry. However,
            # look into the ending string line is the value in the token object.
            line = (if token.lines[0] notin [0, -1]: token.lines[0] else: token.line)
            start = token.start
            lines = (if token.lines[0] == 0: [-1, -1] else: token.lines)
            `end` = token.`end`
            str = token.`$`
            list = token.list

        let tid_len = ($tid).len
        let kind_len = kind.len
        let line_len = ($line).len
        let start_len = ($start).len
        let end_len = ($`end`).len
        var lines_len = 0
        if lines != [-1, -1]:
            # Get the lengths of each number and add 1 for the comma.
            lines_len = ($lines[0]).len + ($lines[1]).len + 1
        let str_len = str.len
        let list_len = (if list: 4 else: 0)

        let line_col = ($(start - LINESTARTS[line])).len

        # if (i === 0) output.add(separator, "\n"); // After header only.
        output.add(separator) # After every row.
        output.add("\n") # After every row.

        for i, label in TB_LABELS:
            var nstr = ""
            var nlen = 0
            block caseInner:
                case i:
                 # TB_LABELS = "tid", "kind", "line", "column", "start", "end", "lines", "$", "list", "value"
                of 0:
                    nstr = $tid & ""
                    nlen = tid_len
                    break caseInner
                of 1:
                    nstr = kind
                    nlen = kind_len
                    break caseInner
                of 2:
                    nstr = $line & ""
                    nlen = line_len
                    break caseInner
                of 3:
                    nstr = $(start - LINESTARTS[line])
                    nlen = line_col
                    break caseInner
                of 4:
                    nstr = $start & ""
                    nlen = start_len
                    break caseInner
                of 5:
                    nstr = $`end` & ""
                    nlen = end_len
                    break caseInner
                of 6:
                    nstr = ""
                    if lines != [-1, -1]:
                        # Get the lengths of each number and add 1 for the comma.
                        nstr = $(lines[0]) & "," & $(lines[1])
                    nlen = lines_len
                    break caseInner
                of 7: # Interpolated string value.
                    nstr = str
                    nlen = str_len
                    break caseInner
                of 8:
                    nstr = (if list: "true" else: "")
                    nlen = list_len
                    break caseInner
                of 9: # Original file substring value.
                    if `end` != -1:
                        nstr = text[start .. `end`]
                        nlen = nstr.len
                    else:
                        nstr = ""
                        nlen = 0
                    break caseInner

             # When the kind is tkEOP clear the value to an empty string.
            if i == 3 and kind == "tkEOP":
                nstr = ""
                nlen = 0

            # Replace newline and tab characters with respective symbol.
            # No need to reset nlen as the replacing is only overwriting
            # a character for another.
            if i == 7 or i == 9:
                # [https://stackoverflow.com/a/34936253]
                # nstr = nstr.replace(/[\r\n]|\t/g, (match) => (match === "\n") ? "⏎" : "⇥")
                nstr = replace(nstr, R, proc (match: string): string =
                    return (if match == "\n": "⏎" else: "⇥")
                )

# tid,kind,line,start,end,lines,$,list,value
# 0,tkCMT,1,0,8,,,,# comment
# 7,tkCMT,7,15,25,,,,# comment 2
# 9,tkCMT,8,27,37,,,,# comment 3
# 14,tkCMT,12,42,51,,,,#comment 4

            # Escape ';' characters when saving to CVS format.
            row.add(nstr.replace(R_semicolon, proc (match: string): string =
                if i == 7 or i == 9:
                    return ("\\" & $CSV_DELIMITER)
            ))

            # // Replace newline characters with raw/escaped character.
            # if nstr.len == 1 and nstr == "\n":
            #   nstr = "\\n"
            #   nlen = 2
            var nlabel = " " & nstr & " ".repeat(abs(tbdb_lens[label] - nlen) + 1)
            if i == 0: # first label
                output.add(TB_MIDDLE_PIPE)
                output.add(nlabel)
            elif l - 1 == i: # last label
                rows.add(row.join($CSV_DELIMITER))
                output.add(TB_MIDDLE_PIPE)
                output.add(nlabel)
                output.add(TB_MIDDLE_PIPE)
            else:
                output.add(TB_MIDDLE_PIPE)
                output.add(nlabel)
    output.add("\n")

    # var tail = TB_BOTTOM_LEFT_CORNER & separator[1 .. ^2] & TB_BOTTOM_RIGHT_CORNER
    # output.add(tail.replace(TB_MIDDLE_CROSS, TB_MIDDLE_T_BOTTOM));
    output.add(
        separator.multiReplace([
            (TB_MIDDLE_T_LEFT, TB_BOTTOM_LEFT_CORNER),
            (TB_MIDDLE_CROSS, TB_MIDDLE_T_BOTTOM),
            (TB_MIDDLE_T_RIGHT, TB_BOTTOM_RIGHT_CORNER)
        ])
    )

    # for (let i = 0, l = TB_LABELS.len; i < l; i++) {
    #   let label = TB_LABELS[i]
    #   if (i === 0) { // first label
    #       output.add(TB_BOTTOM_LEFT_CORNER)
    #       output.add(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
    #   elif: l - 1 === i) { // last label
    #       output.add(TB_MIDDLE_T_BOTTOM)
    #       output.add(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
    #       output.add(TB_BOTTOM_RIGHT_CORNER)
    #   else:
    #       output.add(TB_MIDDLE_T_BOTTOM)
    #       output.add(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
    #   }
    # }
    # console.table(tokens, ["kind", "line", "start", "end", "lines", "$", "list", "value"])

    # Generate JSON from tokens/branches.
    var nodes = %(tokens)
    for i, node in enumerate(nodes):
        if node["str_rep"].getStr() == "":
            node.delete("str_rep")
        if node["$"].getStr() == "":
            node.delete("$")
        if node["lines"][0].getInt() == -1 and
            node["lines"][1].getInt() == -1:
            node.delete("lines")
        if node["list"].getBool == false:
            node.delete("list")

    # return header+output.join("")
    return [
        header & output.join(""),
        rows.join("\n"),
        pretty(nodes, 4)
    ]

    # console.log("---------- BREAKDOWN ----------")
    # console.log("token_count:", tokens.len)
    # console.log("branches_count:", branches.len)
    # console.log(branches)
    # console.log(tbdb_lens)
    # console.table(tokens, ["kind", "line", "start", "end", "lines", "$", "list", "value"])

    # module.exports = { tables, collens }


proc dbugger*(tokens: seq[Token], BRANCHES: seq[seq[Token]],
    text, action: string, LINESTARTS: Table[int, int], tks = false, brs = false) =

    var tbdb_lens = initTable[string, int]()
    # Populate table with label keys with labels and their respective lengths.
    for label in TB_LABELS:
        if label notin tbdb_lens:
            tbdb_lens[label] = label.len

    # var nodes = %(tokens[0])
    # echo t.dtype(nodes)
    # for value, node in pairs(nodes):
    #     echo value
    #     # echo $i & " -> " & $node
    # echo t.dtype(%(tokens[0]))

    if tks:
        # [https://github.com/nim-lang/Nim/issues/8818]
        # [https://forum.nim-lang.org/t/6700]
        # [https://stackoverflow.com/a/26194852]
        var nodes = %(tokens)
        for i, node in enumerate(nodes):
            if node["str_rep"].getStr() == "":
                node.delete("str_rep")
            if node["$"].getStr() == "":
                node.delete("$")
            if node["lines"][0].getInt() == -1 and
                node["lines"][1].getInt() == -1:
                node.delete("lines")
            if node["list"].getBool == false:
                node.delete("list")

        collens(tokens, tbdb_lens, LINESTARTS)
        var bid = 0
        let res = tables(tokens, text, tbdb_lens, "tokens", LINESTARTS, bid)
        let table = res[0]
        let csv = res[1]
        let json = res[2]
        echo table
        echo fmt" tokens_count: {tokens.len}" & "\n"
        let csvheader = TB_LABELS.join($CSV_DELIMITER) & "\n"
        write(joinPath(currentSourcePath().parentDir(), action & ".debug-t.csv"), stripansi(csvheader & csv))
        # write(joinPath(currentSourcePath().parentDir(), action & ".debug-t.json"), json)
        write(joinPath(currentSourcePath().parentDir(), action & ".debug-t.json"), pretty(nodes, 4))

    if brs:
        # Loop over every branch to get table length data.
        for branch in BRANCHES:
            collens(branch, tbdb_lens, LINESTARTS)

        var nodes = %(BRANCHES)
        for branch in nodes:
            for i, node in enumerate(branch):
                if node["str_rep"].getStr() == "":
                    node.delete("str_rep")
                if node["$"].getStr() == "":
                    node.delete("$")
                if node["lines"][0].getInt() == -1 and
                    node["lines"][1].getInt() == -1:
                    node.delete("lines")
                if node["list"].getBool == false:
                    node.delete("list")

        # Loop over every branch to build table data output.
        var output: seq[string] = @[]
        var csvout: seq[string] = @[TB_LABELS.join($CSV_DELIMITER)]
        var jsonout: seq[string] = @[]
        let l = BRANCHES.len
        for i, branch in BRANCHES:
            var index = i
            let res = tables(branch, text, tbdb_lens, "branches", LINESTARTS, index)
            let table = res[0]
            let csv = res[1]
            let json = res[2]
            output.add(table)
            csvout.add(fmt";Branch ─ {index+1}")
            csvout.add(csv)
            jsonout.add(json)
            if l - 1 != i: jsonout.add(",")
        echo output.join("\n")
        echo fmt" branches_count: {BRANCHES.len}"
        write(joinPath(currentSourcePath().parentDir(), action & ".debug-b.csv"), stripansi(csvout.join("\n")))
        # write(joinPath(currentSourcePath().parentDir(), action & ".debug-b.json"), "[\n" & jsonout.join("\n") & "\n]")
        write(joinPath(currentSourcePath().parentDir(), action & ".debug-b.json"), pretty(nodes, 4))

    exit()
