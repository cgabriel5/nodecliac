import std/[tables, sets, re, strutils, sequtils, algorithm]

# from std/sequtils import toSeq

import ./helpers/[types]
# import ./utils/types as t
import ./utils/regex
import lexer, defvars, issue
import validation, acdef, formatter, debugger

let R = re"(?<!\\)\$\{\s*[^}]*\s*\}"

proc parser*(action, text, cmdname, source: string,
            fmt: tuple, trace, igc, test, tks, brs: bool): tuple =

    var ttid = 0
    var NEXT: seq[string] = @[]
    var SCOPE: seq[string] = @[]
    var branch: seq[Token] = @[]
    var BRANCHES: seq[seq[Token]] = @[]
    var oneliner = -1

    # Use ref sequences to mimic Python/JS objects.
    # [https://forum.nim-lang.org/t/1787]
    # [https://forum.nim-lang.org/t/6457]
    # [https://forum.nim-lang.org/t/3870]
    # [https://www.reddit.com/r/nim/comments/rpw5xf/difference_between_ref_and_a_var_inside_proc/]
    # var chain: seq[int] = @[]
    # var chain = new seq[int]
    var chain: ref seq[int] = new seq[int]
    # var CCHAINS: seq[seq[seq[int]]] = @[]
    var CCHAINS: seq[seq[ref seq[int]]] = @[]

    # var ubids: seq[int] = @[]
    var FLAGS = initTable[string, seq[Flag]]()
    var flag: Flag

    # var setting: seq[int] = @[]
    var setting: ref seq[int] = new seq[int]
    var SETTINGS: seq[ref seq[int]] = @[]

    var variable: seq[int] = @[]
    var VARIABLES: seq[seq[int]] = @[]

    var USED_VARS = initTable[string, int]()
    var USER_VARS = initTable[string, seq[int]]()
    var VARSTABLE = builtins(cmdname)
    # var VARSTABLE = initTable[string, string]()
    var vindices = OrderedTableRef[int, seq[seq[int]]]()

    var (tokens, ttypes, ttids, dtids, LINESTARTS) = lexer.tokenizer(text)

    var i = 0
    let l = tokens.len

    var A = Args(action: action, source: source, fmt: fmt,
        trace: trace, igc: igc, test: test, tokens: tks, branches: brs)
    var S = ParseState(tid: -1, filename: source, text: text, args: A,
        # Note: Does this create a copy of the original data?
        lexerdata: (tokens, ttypes, ttids, dtids, LINESTARTS))
    S.excludes = @[]
    S.warn_lines = initHashSet[int]()
    S.warn_lsort = initHashSet[int]()
    S.warnings = newTable[int, seq[Warning]]()

    # Don't need since Nim, like Python, has ^1 to get last value from
    # array and string slicing built-in.
    # proc lastn(list: openarray[any], offset: int = -1) =
    #     return list[list.len + offset]
    # proc strfrmpts() =
    # let strfrmpts = (s, start, end) => s.substring(start, end + 1)

    # let lastn = (list, offset = -1) => list[list.len + offset]
    # let strfrmpts = (s, start, end) => s.substring(start, end + 1)

    proc tkstr(S: ParseState, tid: int): string =
        if tid == -1: return ""
        if S.lexerdata.tokens[tid].kind == "tkSTR":
            if S.lexerdata.tokens[tid].`$` != "":
                return S.lexerdata.tokens[tid].`$`
        return S.text[S.lexerdata.tokens[tid].start .. S.lexerdata.tokens[tid].`end`]

    proc err(tid: var int, message: var string, pos: string = "start", scope: string = "") =
        # When token ID points to end-of-parsing token,
        # reset the id to the last true token before it.
        if S.lexerdata.tokens[tid].kind == "tkEOP":
            tid = S.lexerdata.ttids[^1]

        let token = S.lexerdata.tokens[tid]
        let line = token.line
        let index = if pos == "start": token.start else: token.`end`
        # let msg = message
        let col = index - S.lexerdata.LINESTARTS[line]

        if message.endsWith(":"):
            message &= " '" & tkstr(S, tid) & "'"

        # # Add token debug information.
        # dbeugmsg = "\n\n\033[1mToken\033[0m: "
        # dbeugmsg += "\n - tid: " + str(token["tid"])
        # dbeugmsg += "\n - kind: " + token["kind"]
        # dbeugmsg += "\n - line: " + str(token["line"])
        # dbeugmsg += "\n - start: " + str(token["start"])
        # dbeugmsg += "\n - end: " + str(token["end"])
        # dbeugmsg += "\n __val__: [" + tkstr(tid) + "]"

        # dbeugmsg += "\n\n\033[1mExpected\033[0m: "
        # for n in NEXT:
        #     if not n: n = "\"\""
        #     dbeugmsg += "\n - " + n
        # dbeugmsg += "\n\n\033[1mScopes\033[0m: "
        # for s in SCOPE:
        #     dbeugmsg += "\n - " + s
        # decor = "-" * 15
        # msg += "\n\n" + decor + " TOKEN_DEBUG_INFO " + decor
        # msg += dbeugmsg
        # msg += "\n\n" + decor + " TOKEN_DEBUG_INFO " + decor

        issue_error(S.filename, line, col, message)

    proc warn(tid: int, message: var string) =
        let token = S.lexerdata.tokens[tid]
        let line = token.line
        let index = token.start
        let col = index - S.lexerdata.LINESTARTS[line]

        if message.endsWith(":"): message &= " '" & tkstr(S, tid) & "'"

        # if line notin S.warnings:
        if not S.warnings.hasKey(line):
            S.warnings[line] = @[]
        var warning: Warning
        warning = (S.filename, line, col, message)
        S.warnings[line].add(warning)
        S.warn_lines.incl(line)

    # proc hint(tid: int, message: var string) =
    #     let token = S.lexerdata.tokens[tid]
    #     let line = token.line
    #     let index = token.start
    #     let col = index - S.lexerdata.LINESTARTS[line]

    #     if message.endsWith(":"):
    #         message &= " '" & tkstr(S, tid) & "'"

    #     issue_hint(S.filename, line, col, message)

    proc addtoken(S: ParseState, i: int) =
        # Interpolate/track interpolation indices for string.
        if S.lexerdata.tokens[i].kind == "tkSTR":
            let value = tkstr(S, i)
            S.lexerdata.tokens[i].`$` = value

            if S.args.action != "format" and i notin vindices:
                var `end` = 0
                var `pointer` = 0
                var tmpstr = ""
                vindices[i] = @[]

                var matches = findAllBounds(value, R)
                if matches.len > 0:
                    for match in matches:
                        let start = match.first
                        `end` = match.last + 1
                        let varname = value[start + 2 .. `end` - 2].strip(trailing=true)

                        if varname notin VARSTABLE:
                            # Note: Modify token index to point to
                            # start of the variable position.
                            S.lexerdata.tokens[S.tid].start += start
                            var msg = "Undefined variable"
                            err(ttid, msg, scope="child")

                        USED_VARS[varname] = 1
                        vindices[i].add(@[start, `end`])

                        tmpstr &= value[`pointer` ..< start]
                        let sub = VARSTABLE.getOrDefault(varname, "")

                        tmpstr &= (
                            if sub != "":
                                if sub[0] notin {'"', '\''}: sub
                                # Unquote string if quoted.
                                else: sub[1 .. ^2]
                            else: sub
                        )
                        `pointer` = `end`

                    # Get tail-end of string.
                    tmpstr &= value[`end` .. ^1]
                    S.lexerdata.tokens[i].`$` = tmpstr

                    if vindices[i].len == 0: vindices.del(i)

        BRANCHES[^1].add(S.lexerdata.tokens[i])

    proc expect(args: varargs[string]) =
        NEXT.setLen(0)
        for a in args:
            NEXT.add(a)

    proc clearscope() =
        SCOPE.setLen(0)

    proc addscope(s: string) =
        SCOPE.add(s)

    proc popscope(p: int = 1) =
        var pops = p
        # [TODO] Use while loop for now. Revisit countdown loop?
        # for i in countdown(p, pops):
        #     discard SCOPE.pop()
        while (pops > 0):
            discard SCOPE.pop()
            pops -= 1

    proc hasscope(s: string): bool =
        return s in SCOPE

    proc prevscope(): string =
        return SCOPE[^1]

    proc hasnext(s: string): bool =
        return s in NEXT

    proc nextany(): bool =
        return NEXT[0] == ""

    proc addbranch() =
        BRANCHES.add(branch)

    proc newbranch() =
        branch = @[]

    proc prevtoken(S: ParseState): Token =
        return S.lexerdata.tokens[S.lexerdata.dtids[$(S.tid)]]

    # Command chain/flag grouping helpers.
    # ================================

    proc newgroup() =
        chain = new seq[int]

    proc addtoken_group(i: int) =
        chain[].add(i)

    proc addgroup(g: ref seq[int]) =
        CCHAINS.add(@[g])

    proc addtoprevgroup() =
        newgroup()
        CCHAINS[^1].add(chain)

    # ============================

    proc newvaluegroup(prop: string) =
        if prop == "values":
            flag.values.add(@[-1])

    proc setflagprop(prop: string, prev_val_group: bool = false) =
        let index = $(CCHAINS.len - 1)

        if prop != "values":
            case prop:
            of "tid":        FLAGS[index][^1].tid = S.tid
            of "alias":      FLAGS[index][^1].alias = S.tid
            of "boolean":    FLAGS[index][^1].boolean = S.tid
            of "assignment": FLAGS[index][^1].assignment = S.tid
            of "multi":      FLAGS[index][^1].multi = S.tid
            of "union":      FLAGS[index][^1].union = S.tid
            else: discard
        else:
            if not prev_val_group:
                FLAGS[index][^1].values.add(@[S.tid])
            else:
                FLAGS[index][^1].values[^1].add(S.tid)

    proc newflag() =
        flag = Flag()
        flag.tid = -1
        flag.alias = -1
        flag.boolean = -1
        flag.assignment = -1
        flag.multi = -1
        flag.union = -1
        flag.values = @[]

        let index = CCHAINS.len - 1
        if $index notin FLAGS: FLAGS[$index] = @[]
        FLAGS[$index].add(flag)
        setflagprop("tid")

    # Setting/variable grouping helpers.
    # ================================

    proc newgroup_stn() =
        # setting = @[]
        setting = new seq[int]

    proc addtoken_stn_group(i: int) =
        setting[].add(i)

    proc addgroup_stn(g: ref seq[int]) =
        SETTINGS.add(g)

    # proc addtoprevgroup_stn() =
    #   newgroup_stn()
    #   SETTINGS[^1].add(setting)

    # ============================

    proc newgroup_var() =
        variable = @[]

    proc addtoken_var_group(i: int) =
        variable.add(i)

    proc addgroup_var(g: seq[int]) =
        VARIABLES.add(g)

    # proc addtoprevgroup_var() =
    #     newgroup_var()
    #     VARIABLES.back().push_back(variable)

    while i < l:
        let token = tokens[i]
        let kind = token.kind
        let line = token.line
        # start = token.start
        # `end` = token.`end`
        S.tid = token.tid

        if kind == "tkNL":
            i += 1
            continue

        if kind != "tkEOP":
            ttid = i

        if kind == "tkTRM":
            if SCOPE.len == 0:
                addbranch()
                addtoken(S, ttid)
                newbranch()
                expect("")
            else:
                addtoken(S, ttid)

                if NEXT.len > 0 and not nextany():
                    var msg = "Improper termination"
                    err(ttid, msg, "start", "child")

            i += 1
            continue

        if SCOPE.len == 0:
            oneliner = -1

            if BRANCHES.len > 0:
                let ltoken = BRANCHES[^1][^1] # Last branch token.
                if line == ltoken.line and ltoken.kind != "tkTRM":
                    var msg = "Improper termination"
                    err(ttid, msg, scope = "parent")

            if kind != "tkEOP":
                addbranch()
                addtoken(S, ttid)

                if kind in ["tkSTN", "tkVAR", "tkCMD"]:
                    addscope(kind)
                    if kind == "tkSTN":
                        newgroup_stn()
                        addgroup_stn(setting)
                        addtoken_stn_group(S.tid)

                        vsetting(S)
                        expect("", "tkASG")
                    elif kind == "tkVAR":
                        newgroup_var()
                        addgroup_var(variable)
                        addtoken_var_group(S.tid)

                        let varname = tkstr(S, S.tid)[1..^1]
                        VARSTABLE[varname] = ""

                        if varname notin USER_VARS:
                            USER_VARS[varname] = @[]
                        USER_VARS[varname].add(S.tid)

                        vvariable(S)
                        expect("", "tkASG")
                    elif kind == "tkCMD":
                        addtoken_group(S.tid)
                        addgroup(chain)

                        expect("", "tkDDOT", "tkASG", "tkDCMA")

                        let command = tkstr(S, S.tid)
                        if command != "*" and command != cmdname:
                            var msg = "Unexpected command:"
                            warn(S.tid, msg)
                else:
                    if kind == "tkCMT":
                        newbranch()
                        expect("")
                    else:
                        # Handle unexpected parent tokens.
                        var msg = "Unexpected token:"
                        err(S.tid, msg, scope = "parent")
        else:
            if kind == "tkCMT":
                addtoken(S, ttid)
                i += 1
                continue

            # Remove/add necessary tokens when parsing long flag form.
            if hasscope("tkBRC_LB"):
                if hasnext("tkDPPE"):
                    # Remove "tkDPPE"
                    NEXT.delete(NEXT.find("tkDPPE"))
                    NEXT.add("tkFLG")
                    NEXT.add("tkKYW")
                    NEXT.add("tkBRC_RB")

            if NEXT.len > 0 and not hasnext(kind):
                if nextany():
                    clearscope()
                    newbranch()

                    newgroup()
                    # i += 1
                    continue
                else:
                    var msg = "Unexpected token:"
                    err(S.tid, msg, scope = "child")

            addtoken(S, ttid)

            # Oneliners must be declared on oneline, else error.
            if BRANCHES[^1][0].kind == "tkCMD" and (
                ((hasscope("tkFLG") or hasscope("tkKYW")) or
                kind in ["tkFLG", "tkKYW"]) and
                not hasscope("tkBRC_LB")):
                if oneliner == -1:
                    oneliner = token.line
                elif token.line != oneliner:
                    var msg = "Improper oneliner"
                    err(S.tid, msg, scope = "child")

            case prevscope():
            of "tkSTN":
                case (kind):
                of "tkASG":
                    addtoken_stn_group(S.tid)

                    expect("tkSTR", "tkAVAL")

                of "tkSTR":
                    addtoken_stn_group(S.tid)

                    expect("")

                    vstring(S)

                of "tkAVAL":
                    addtoken_stn_group(S.tid)

                    expect("")

                    vsetting_aval(S)
                else: discard

            of "tkVAR":
                case (kind):
                of "tkASG":
                    addtoken_var_group(S.tid)

                    expect("tkSTR")

                of "tkSTR":
                    addtoken_var_group(S.tid)
                    VARSTABLE[tkstr(S, BRANCHES[^1][^3].tid)[1..^1]] = tkstr(S, S.tid)

                    expect("")

                    vstring(S)

            of "tkCMD":
                case (kind):
                of "tkASG":
                    # If a universal block, store group id.
                    if $(S.tid) in S.lexerdata.dtids:
                        let prevtk = prevtoken(S)
                        if prevtk.kind == "tkCMD" and S.text[prevtk.start] == '*':
                            S.ubids.add(CCHAINS.len - 1)
                    expect("tkBRC_LB", "tkFLG", "tkKYW")

                of "tkBRC_LB":
                    addscope(kind)
                    expect("tkFLG", "tkKYW", "tkBRC_RB")

                # # [TODO] Pathway needed?
                # of "tkBRC_RB":
                #   expect("", "tkCMD")

                of "tkFLG":
                    newflag()

                    addscope(kind)
                    expect("", "tkASG", "tkQMK", "tkDCLN", "tkFVAL", "tkDPPE", "tkBRC_RB")

                of "tkKYW":
                    newflag()

                    addscope(kind)
                    expect("tkSTR", "tkDLS")

                of "tkDDOT":
                    expect("tkCMD", "tkBRC_LC")

                of "tkCMD":
                    addtoken_group(S.tid)

                    expect("", "tkDDOT", "tkASG", "tkDCMA")

                of "tkBRC_LC":
                    addtoken_group(-1)

                    addscope(kind)
                    expect("tkCMD")

                of "tkDCMA":
                    # If a universal block, store group id.
                    if $(S.tid) in S.lexerdata.dtids:
                        let prevtk = prevtoken(S)
                        if prevtk.kind == "tkCMD" and S.text[prevtk.start] == '*':
                            S.ubids.add(CCHAINS.len - 1)

                    addtoprevgroup()

                    addscope(kind)
                    expect("tkCMD")

            of "tkBRC_LC":
                case (kind):
                of "tkCMD":
                    addtoken_group(S.tid)

                    expect("tkDCMA", "tkBRC_RC")

                of "tkDCMA":
                    expect("tkCMD")

                of "tkBRC_RC":
                    addtoken_group(-1)

                    popscope(1)
                    expect("", "tkDDOT", "tkASG", "tkDCMA")

            of "tkFLG":
                case (kind):
                of "tkDCLN":
                    if prevtoken(S).kind != "tkDCLN":
                        expect("tkDCLN")
                    else:
                        expect("tkFLGA")

                of "tkFLGA":
                    setflagprop("alias", false)

                    expect("", "tkASG", "tkQMK", "tkDPPE")


                of "tkQMK":
                    setflagprop("boolean", false)

                    expect("", "tkDPPE")


                of "tkASG":
                    setflagprop("assignment", false)

                    expect("", "tkDCMA", "tkMTL", "tkDPPE", "tkBRC_LP", "tkFVAL", "tkSTR", "tkDLS", "tkBRC_RB")

                of "tkDCMA":
                    setflagprop("union", false)

                    expect("tkFLG", "tkKYW")

                of "tkMTL":
                    setflagprop("multi", false)

                    expect("", "tkBRC_LP", "tkDPPE")

                of "tkDLS":
                    addscope(kind)
                    expect("tkBRC_LP")

                of "tkBRC_LP":
                    addscope(kind)
                    expect("tkFVAL", "tkSTR", "tkFOPT", "tkDLS", "tkBRC_RP")

                of "tkFLG":
                    newflag()

                    if hasscope("tkBRC_LB") and token.line == prevtoken(S).line:
                        var msg = "Flag same line (nth)"
                        err(S.tid, msg, "start", "child")
                    expect("", "tkASG", "tkQMK", "tkDCLN", "tkFVAL", "tkDPPE")

                of "tkKYW":
                    newflag()

                    # [TODO] Investigate why leaving flag scope doesn't affect
                    # parsing. For now remove it to keep scopes array clean.
                    popscope(1)

                    if hasscope("tkBRC_LB") and token.line == prevtoken(S).line:
                        var msg = "Keyword same line (nth)"
                        err(S.tid, msg, "start", "child")
                    addscope(kind)
                    expect("tkSTR", "tkDLS")

                of "tkSTR":
                    setflagprop("values", false)

                    expect("", "tkDPPE")

                of "tkFVAL":
                    setflagprop("values", false)

                    expect("", "tkDPPE")

                of "tkDPPE":
                    expect("tkFLG", "tkKYW")

                of "tkBRC_RB":
                    popscope(1)
                    expect("")

            of "tkBRC_LP":
                case (kind):
                of "tkFOPT":
                    let prevtk = prevtoken(S)
                    if prevtk.kind == "tkBRC_LP":
                        if prevtk.line == line:
                            var msg = "Option same line (first)"
                            err(S.tid, msg, "start", "child")
                        addscope("tkOPTS")
                        expect("tkFVAL", "tkSTR", "tkDLS")

                of "tkFVAL":
                    setflagprop("values", false)

                    expect("tkFVAL", "tkSTR", "tkDLS", "tkBRC_RP", "tkTBD")
                    # # Disable pathway for now.
                    # when "tkTBD":
                    #   setflagprop("values", false)

                    #   expect("tkFVAL", "tkSTR", "tkDLS", "tkBRC_RP", "tkTBD")

                of "tkSTR":
                    setflagprop("values", false)

                    expect("tkFVAL", "tkSTR", "tkDLS", "tkBRC_RP", "tkTBD")

                of "tkDLS":
                    addscope(kind)
                    expect("tkBRC_LP")
                    # # [TODO] Pathway needed?
                    # when "tkDCMA":
                    #   expect("tkFVAL", "tkSTR")

                of "tkBRC_RP":
                    popscope(1)
                    expect("", "tkDPPE")

                    let prevtk = prevtoken(S)
                    if prevtk.kind == "tkBRC_LP":
                        var msg = "Empty scope (flag)"
                        warn(prevtk.tid, msg)

                # # [TODO] Pathway needed?
                # when "tkBRC_RB":
                #   popscope(1)
                #   expect("")

            of "tkDLS":
                case (kind):
                of "tkBRC_LP":
                    newvaluegroup("values")
                    setflagprop("values", true)

                    expect("tkSTR")

                of "tkDLS":
                    expect("tkSTR")

                of "tkSTR":
                    expect("tkDCMA", "tkBRC_RP")

                of "tkDCMA":
                    expect("tkSTR", "tkDLS")

                of "tkBRC_RP":
                    popscope(1)

                    setflagprop("values", true)

                    # Handle: 'program = --flag=$("cmd")'
                    # Handle: 'program = default $("cmd")'
                    if prevscope() in ["tkFLG", "tkKYW"]:
                        if hasscope("tkBRC_LB"):
                            popscope(1)
                            expect("tkFLG", "tkKYW", "tkBRC_RB")
                        else:
                            # Handle: oneliner command-string
                            # 'program = --flag|default $("cmd", $"c", "c")'
                            # 'program = --flag::f=(1 3)|default $("cmd")|--flag'
                            # 'program = --flag::f=(1 3)|default $("cmd")|--flag'
                            # 'program = default $("cmd")|--flag::f=(1 3)'
                            # 'program = default $("cmd")|--flag::f=(1 3)|default $("cmd")'
                            expect("", "tkDPPE", "tkFLG", "tkKYW")

                        # Handle: 'program = --flag=(1 2 3 $("c") 4)'
                    elif prevscope() == "tkBRC_LP":
                        expect("tkFVAL", "tkSTR", "tkFOPT", "tkDLS", "tkBRC_RP")

                        # Handle: long-form
                        # 'program = [
                        #   --flag=(
                        #       - 1
                        #       - $("cmd")
                        #       - true
                        #   )
                        # ]'
                    elif prevscope() == "tkOPTS":
                        expect("tkFOPT", "tkBRC_RP")

            of "tkOPTS":
                case (kind):
                of "tkFOPT":
                    if prevtoken(S).line == line:
                        var msg = "Option same line (nth)"
                        err(S.tid, msg, "start", "child")
                    expect("tkFVAL", "tkSTR", "tkDLS")

                of "tkDLS":
                    addscope("tkDLS") # Build cmd-string.
                    expect("tkBRC_LP")

                of "tkFVAL":
                    setflagprop("values", false)

                    expect("tkFOPT", "tkBRC_RP")

                of "tkSTR":
                    setflagprop("values", false)

                    expect("tkFOPT", "tkBRC_RP")

                of "tkBRC_RP":
                    popscope(2)
                    expect("tkFLG", "tkKYW", "tkBRC_RB")

            of "tkBRC_LB":
                case (kind):
                of "tkFLG":
                    newflag()

                    if hasscope("tkBRC_LB") and token.line == prevtoken(S).line:
                        var msg = "Flag same line (first)"
                        err(S.tid, msg, "start", "child")
                    addscope(kind)
                    expect("tkASG", "tkQMK", "tkDCLN", "tkFVAL", "tkDPPE", "tkBRC_RB")

                of "tkKYW":
                    newflag()

                    if hasscope("tkBRC_LB") and token.line == prevtoken(S).line:
                        var msg = "Keyword same line (first)"
                        err(S.tid, msg, "start", "child")
                    addscope(kind)
                    expect("tkSTR", "tkDLS", "tkBRC_RB")

                of "tkBRC_RB":
                    popscope(1)
                    expect("")

                    let prevtk = prevtoken(S)
                    if prevtk.kind == "tkBRC_LB":
                        var msg = "Empty scope (command)"
                        warn(prevtk.tid, msg)

            of "tkKYW":
                case (kind):
                of "tkSTR":
                    setflagprop("values", false)

                    # Collect exclude values for use upstream.
                    if $(S.tid) in S.lexerdata.dtids:
                        let prevtk = prevtoken(S)
                        if prevtk.kind == "tkKYW" and
                            tkstr(S, prevtk.tid) == "exclude":
                            let excl_values = tkstr(S, S.tid)[1 .. ^2].strip(trailing=true).split(";")
                            for exclude in excl_values: S.excludes.add(exclude)

                    # [TODO] This pathway re-uses the flag (tkFLG) token
                    # pathways. If the keyword syntax were to change
                    # this will need to change as it might no loner work.
                    popscope(1)
                    addscope("tkFLG") # Re-use flag pathways for now.
                    expect("", "tkDPPE")

                of "tkDLS":
                    addscope(kind)
                    expect("tkBRC_LP")
                    # # [TODO] Pathway needed?
                    # when "tkBRC_RB":
                    #   popscope(1)
                    #   expect("")
                    # # [TODO] Pathway needed?
                    # when "tkFLG":
                    #   expect("tkASG", "tkQMK"
                    #       "tkDCLN", "tkFVAL", "tkDPPE")
                    # # [TODO] Pathway needed?
                    # when "tkKYW":
                    #   addscope(kind)
                    #   expect("tkSTR", "tkDLS")

                of "tkDPPE":
                    # [TODO] Because the flag (tkFLG) token pathways are
                    # reused for the keyword (tkKYW) pathways, the scope
                    # needs to be removed. This is fine for now but when
                    # the keyword token pathway change, the keyword
                    # pathways will need to be fleshed out in the future.
                    if prevscope() == "tkKYW":
                        popscope(1)
                        addscope("tkFLG") # Re-use flag pathways for now.
                    expect("tkFLG", "tkKYW")

            of "tkDCMA":
                case (kind):
                of "tkCMD":
                    addtoken_group(S.tid)

                    popscope(1)
                    expect("", "tkDDOT", "tkASG", "tkDCMA")

                    let command = tkstr(S, S.tid)
                    if command != "*" and command != cmdname:
                        var msg = "Unexpected command:"
                        warn(S.tid, msg)

            else:
                var msg = "Unexpected token:"
                err(S.lexerdata.tokens[S.tid].tid, msg, "end", "")

        i += 1

    # Check for any unused variables and give warning.
    for uservar in USER_VARS.keys:
        if uservar notin USED_VARS:
            for tid in USER_VARS[uservar]:
                var msg = "Unused variable: '" & uservar & "'"
                warn(tid, msg)
                S.warn_lsort.incl(tokens[tid].line)

    proc comp(a, b: Warning): int =
        cmp(a[1], b[1]) or cmp(a[2], b[2])

    # Sort warning lines and print issues.
    # [https://github.com/nim-lang/Nim/issues/2485]
    var warnlines = toSeq(items(S.warn_lines))
    warnlines.sort()
    for warnline in warnlines:
        # Only sort lines where unused variable warning(s) were added.
        if S.warn_lsort.contains(warnline) and S.warnings[warnline].len > 1:
            # [https://stackoverflow.com/a/4233482]
            S.warnings[warnline].sort(comp)
            # S["warnings"][warnline].sort(key = operator.itemgetter(1, 2))
            # S.warnings[warnline].sort((a, b) => a[1] - b[1] || a[2] - b[2])
        for warning in S.warnings[warnline]:
            issue_warn(warning.filename, warning.line, warning.col, warning.message)

    if action == "make": return acdef(BRANCHES, CCHAINS, FLAGS, SETTINGS, S, cmdname)
    elif action == "format": return formatter(tokens, text, BRANCHES, CCHAINS, FLAGS, SETTINGS, S)
    elif action == "debug": dbugger(tokens, BRANCHES, text, action, LINESTARTS, tks, brs)
