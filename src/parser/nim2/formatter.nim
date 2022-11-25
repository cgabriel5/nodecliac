import std/[md5, tables, sets]

import ./helpers/[types]
# import ./utils/types as t

proc formatter*(tokens: seq[Token], text: string,
    branches: seq[seq[Token]],
    cchains: seq[seq[ref seq[int]]],
    flags: Table[string, seq[Flag]],
    settings: seq[ref seq[int]],
    S: ParseState): tuple =

    let fmt = S.args.fmt
    # let igc = S.args.igc

    # let ttypes = S.lexerdata.ttypes
    # let ttids = S.lexerdata.ttids
    # let dtids = S.lexerdata.dtids

    # Indentation level multipliers.
    const MXP = {
        "tkCMT": 0,
        "tkCMD": 0,
        "tkFLG": 1,
        "tkFOPT": 2,
        "tkBRC": 0,
        "tkNL": 0,
        "tkSTN": 0,
        "tkVAR": 0,
        "tkBRC_RP": 1,
        "tkBRC_LP": 2
    }.toTable

    const NO_NL_CMT = toHashSet(["tkNL", "tkCMT"])

    let (ichar, iamount) = fmt
    proc indent(`type`: string = "COMMENT", count: int = 0): string =
        let level = if count > 0: count else: MXP[`type`]
        result = ichar.repeat(level * iamount)

    proc tkstr(tid: int): string =
        if tid == -1: return ""
        # Return interpolated string for string tokens.
        if tokens[tid].kind == "tkSTR": return tokens[tid].`$`
        return text[tokens[tid].start .. tokens[tid].`end`]

    proc prevtoken(tid: int, skip: HashSet[string] = toHashSet(["tkNL"])): int =
        for ttid in countdown(tid - 1, 0):
            if tokens[ttid].kind notin skip:
                return ttid
        return -1

    var cleaned: seq[string] = @[]

    # for (let i = 0, l = branches.length; i < l; i++) {
    for branch in branches:
        # let branch = branches[i];

        let parentkind = branch[0].kind

        var first_assignment = false
        var level = 0

        var brc_lp_count = 0
        var group_open = false

        # for (let j = 0, l = branch.length; j < l; j++) {
        for j in countup(0, branch.high):
            let leaf = branch[j]

            let tid = leaf.tid
            let kind = leaf.kind
            let line = leaf.line

            ## Settings / Variables

            if parentkind in ["tkSTN", "tkVAR"]:
                if kind == "tkTRM":
                    cleaned.add(tkstr(leaf.tid))
                    continue

                if tid != 0:
                    let ptk = tokens[prevtoken(tid)]
                    let dline = line - ptk.line
                    if kind in ["tkASG", "tkSTR", "tkAVAL"]:
                        if ptk.kind == "tkCMT":
                            cleaned.add("\n")
                            if dline > 1: cleaned.add("\n")
                        cleaned.add(" ")
                    else:
                        if dline == 0: cleaned.add(" ")
                        elif dline == 1: cleaned.add("\n")
                        else: cleaned.add("\n\n")

                cleaned.add(tkstr(leaf.tid))

                ## Command chains
            elif parentkind in ["tkCMD"]:
                if tid != 0:
                    let ptk = tokens[prevtoken(tid)]
                    let dline = line - ptk.line

                    if dline == 1:
                        cleaned.add("\n")
                    elif dline > 1:
                        if not group_open:
                            cleaned.add("\n")
                            cleaned.add("\n")

                            # [TODO] Add format settings to customize formatting.
                            # For example, collapse newlines in flag scopes?
                            # if level > 0: cleaned.pop()

                # When inside an indentation level or inside parenthesis,
                # append a space before every token to space things out.
                # However, because this is being done lazily, some token
                # conditions must be skipped. The skippable cases are when
                # a '$' precedes a string (""), i.e. a '$"command"'. Or
                # when an eq-sign precedes a '$', i.e. '=$("cmd")',
                if (level > 0 or brc_lp_count == 1) and kind in ["tkFVAL", "tkSTR", "tkDLS", "tkTBD"]:
                    let ptk = tokens[prevtoken(tid, NO_NL_CMT)]
                    let pkind = ptk.kind

                    if (
                        pkind != "tkBRC_LP" and
                        cleaned[^1] != " " and
                        not ((kind == "tkSTR" and pkind == "tkDLS") or (kind == "tkDLS" and pkind == "tkASG"))
                    ):
                        cleaned.add(" ")

                if kind == "tkBRC_LC":
                    group_open = true
                    cleaned.add(tkstr(leaf.tid))
                elif kind == "tkBRC_RC":
                    group_open = false
                    cleaned.add(tkstr(leaf.tid))
                elif kind == "tkDCMA" and not first_assignment:
                    cleaned.add(tkstr(leaf.tid));
                    # Append newline after group is cloased.
                    # if not group_open: cleaned.add("\n")
                elif kind == "tkASG" and not first_assignment:
                    first_assignment = true
                    cleaned.add(" ")
                    cleaned.add(tkstr(leaf.tid))
                    cleaned.add(" ")
                elif kind == "tkBRC_LB":
                    cleaned.add(tkstr(leaf.tid))
                    level = 1
                elif kind == "tkBRC_RB":
                    level = 0
                    first_assignment = false
                    cleaned.add(tkstr(leaf.tid))
                elif kind == "tkFLG":
                    if level > 0: cleaned.add(indent(kind, level))
                    cleaned.add(tkstr(leaf.tid))
                elif kind == "tkKYW":
                    if level > 0: cleaned.add(indent(kind, level))
                    cleaned.add(tkstr(leaf.tid))
                    cleaned.add(" ")
                elif kind == "tkFOPT":
                    level = 2
                    cleaned.add(indent(kind, level))
                    cleaned.add(tkstr(leaf.tid))
                elif kind == "tkBRC_LP":
                    brc_lp_count += 1
                    let ptk = tokens[prevtoken(tid)]
                    let pkind = ptk.kind
                    if pkind notin ["tkDLS", "tkASG", "tkMTL"]:
                        let scope_offset = (pkind == "tkCMT").int
                        cleaned.add(indent(kind, level + scope_offset))
                    cleaned.add(tkstr(leaf.tid))
                elif kind == "tkBRC_RP":
                    brc_lp_count -= 1
                    if level == 2 and brc_lp_count == 0 and branch[j - 1].kind != "tkBRC_LP":
                        cleaned.add(indent(kind, level - 1))
                        level = 1
                    cleaned.add(tkstr(leaf.tid))
                elif kind == "tkCMT":
                    let ptk = tokens[prevtoken(leaf.tid, toHashSet([""]))].kind
                    let atk = tokens[prevtoken(tid)].kind
                    if ptk == "tkNL":
                        var scope_offset = 0
                        if atk == "tkASG": scope_offset = 1
                        cleaned.add(indent(kind, level + scope_offset))
                    else: cleaned.add(" ")
                    cleaned.add(tkstr(leaf.tid))
                else:
                    cleaned.add(tkstr(leaf.tid))

                ## Comments
            elif "tkCMT" == parentkind:
                if tid != 0:
                    let ptk = tokens[prevtoken(tid)]
                    let dline = line - ptk.line

                    if dline == 1:
                        cleaned.add("\n")
                    else:
                        cleaned.add("\n")
                        cleaned.add("\n")
                cleaned.add(tkstr(leaf.tid))
            else:
                if kind notin ["tkTRM"]:
                    cleaned.add(tkstr(leaf.tid))

    # Return empty values to maintain parity with acdef.py.

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
    data.formatted = cleaned.join("") & "\n"
    result = data
