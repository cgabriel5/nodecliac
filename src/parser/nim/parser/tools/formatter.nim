from strformat import fmt
from strutils import repeat
from sequtils import filter
from re import re, replace, replacef, reMultiLine
from "../helpers/types" import State, Node
import tables

# Formats (prettifies) .acmap file.
#
# @param  {object} S - State object.
# @return {string} - The prettied file contents.
proc formatter*(S: var State): tuple =
    let igc = S.args.igc
    var nodes = S.tables.tree["nodes"]
    var output = ""

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

    # Filter comment nodes when flag is provided.
    if igc:
        var flag = false
        nodes = nodes.filter(proc (N: Node): bool =
            # Remove newline node directly after comment node.
            if flag:
                flag = false
                if N.node == "NEWLINE": return false

            var check = N.node != "COMMENT"
            flag = not check
            return check
        )

    # Loop over nodes to build formatted file.
    let l = nodes.len

    for i, N in nodes:
        let `type` = N.node

        case (`type`):
            of "COMMENT":
                let scope = if scopes.len > 0: scopes[^1] else: 0
                let pad = indent(count = scope)

                output &= fmt"{pad}{N.comment.value}"

            of "NEWLINE":
                let nN = if i + 1 < l: nodes[i + 1] else: Node()

                if nl_count <= 1: output &= "\n"
                inc(nl_count)
                if nN.node != "NEWLINE": nl_count = 0

            of "SETTING":
                let nval = N.name.value
                let aval = N.assignment.value
                let vval = N.value.value

                output &= fmt"@{nval} {aval} {vval}"

            of "VARIABLE":
                let nval = N.name.value
                let aval = N.assignment.value
                let vval = N.value.value

                output &= fmt"${nval} {aval} {vval}"

            of "COMMAND":
                let vval = N.value.value
                let cval = N.command.value
                let dval = N.delimiter.value
                let aval = N.assignment.value

                output &= fmt"{cval}{dval} {aval} {vval}"
                if vval != "" and vval == "[": scopes.add(1) # Track scope.

            of "FLAG":
                let kval = N.keyword.value
                let hval = N.hyphens.value
                let nval = N.name.value
                let bval = N.boolean.value
                let aval = N.assignment.value
                let mval = N.multi.value
                let vval = N.value.value
                let singleton = N.singleton
                let pad = indent(count = singleton.int)
                var pipe_del = if singleton: "" else: "|"

                # Note: If nN is a flag reset var.
                if pipe_del != "":
                    let nN = if i + 1 < l: nodes[i + 1] else: Node()
                    if nN.node != "FLAG": pipe_del = ""

                output &= # [https://stackoverflow.com/a/23867090]
                    pad &
                    (if kval != "": kval & " " else: "") &
                    hval &
                    nval &
                    bval &
                    aval &
                    mval &
                    vval &
                    pipe_del

                if vval != "" and vval == "(": scopes.add(2) # Track scope.

            of "OPTION":
                let bval = N.bullet.value
                let vval = N.value.value
                let pad = indent("OPTION")

                output &= fmt"{pad}{bval} {vval}"


            of "BRACE":
                let bval = N.brace.value
                let pad = indent(count = if bval == "]": 0 else: 1)

                output &= fmt"{pad}{bval}"
                discard scopes.pop() # Un-track last scope.

    # Final newline replacements.
    output = output
            .replacef(re("(\\[|\\()$\n{2}", {reMultiLine}), "$1\n")
            .replacef(re("\n{2}([ \t]*)(\\]|\\))$", {reMultiLine}), "\n$1$2")
            .replace(re"^\s*|\s*$")
            # .replacef(re("^((@|\\$).+)$\\n{2,}^(@|\\$)", {reMultiLine}), "$1\n$3")

    if igc: output = output.replacef(re("^(\\s*(-{1}|default).+)$\n{2,}", {reMultiLine}), "$1\n")

    output = output.replace(re(" *$", {reMultiLine})) & "\n"

    var data: tuple[
        acdef: string,
        config: string,
        keywords: string,
        formatted: string,
        placeholders: Table[string, string]
    ]
    data.formatted = output
    result = data
