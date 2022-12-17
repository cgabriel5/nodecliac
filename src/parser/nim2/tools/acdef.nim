import std/[md5, algorithm, sequtils, unicode, re]
import std/[strutils, times, strtabs, sets, tables]

import ../helpers/[types, charsets]
# import ./utils/types as t

proc acdef*(branches: seq[seq[Token]],
    cchains: seq[seq[ref seq[int]]],
    flags: Table[string, seq[Flag]],
    settings: seq[ref seq[int]],
    S: ParseState, cmdname: string): tuple =

    let ubids = S.ubids
    let text = S.text
    let tokens = S.lexerdata.tokens
    let excludes = S.excludes

    var oSets = initOrderedTable[string, OrderedTable[string, int]]()
    var oDefaults = OrderedTableRef[string, OrderedTable[string, int]]()
    var oFiledirs = OrderedTableRef[string, OrderedTable[string, int]]()
    var oContexts = OrderedTableRef[string, OrderedTable[string, int]]()

    var oSettings = initOrderedTable[string, string]()
    var settings_count = 0
    var oTests: seq[string] = @[]
    # var oPlaceholders = initTable[string, string]()
    var oPlaceholders = newStringTable()
    var omd5Hashes = initTable[string, string]()
    var acdef = ""
    var acdef_lines: seq[string] = @[]
    var config = ""
    var defaults = ""
    var filedirs = ""
    var contexts = ""
    var has_root = false

    # Collect all universal block flags.
    var ubflags: seq[Flag] = @[]
    for ubid in ubids:
        for flg in flags[$ubid]:
            ubflags.add(flg)
    var oKeywords: array[3, OrderedTableRef[string, OrderedTable[string, int]]] = [oDefaults, oFiledirs, oContexts]

    # Escape '+' chars in commands.
    let rcmdname = cmdname.replace(re"\+", "\\+")
    var r = re("^(" & rcmdname & "|[-_a-zA-Z0-9]+)")

    let re_space = re("\\s")
    let re_space_cl = re(";\\s+")

    let date = getTime()
    let datestring = date.format("ddd MMM dd yyyy HH:mm:ss")
    let timestamp = date.toUnix()
    let ctime = datestring & " (" & $timestamp & ")"
    var header = "# DON'T EDIT FILE —— GENERATED: " & ctime & "\n\n"
    if S.args.test: header = ""

    proc tkstr(tid: int): string =
        if tid == -1: return ""
        # Return interpolated string for string tokens.
        if tokens[tid].kind == "tkSTR": return tokens[tid].`$`
        return text[tokens[tid].start .. tokens[tid].`end`]

    # compare function: Sorts alphabetically.
    #
    # @param  {string} a - Item a.
    # @param  {string} b - Item b.
    # @return {number} - Sort result.
    #
    # @resource [https://stackoverflow.com/a/6712058]
    # @resource [https://stackoverflow.com/a/42478664]
    # @resource [http://www.fileformat.info/info/charset/UTF-16/list.htm]
    #
    # let asort = (a, b) => {
    # a = a.toLowerCase()
    # b = b.toLowerCase()

    # # Long form: [https://stackoverflow.com/a/9175302]
    # # if (a > b) return 1
    # # else if (a < b) return -1

    # # Second comparison.
    # # if (a.length < b.length) return -1
    # # else if (a.length > b.length) return 1
    # # else return 0

    type Cobj = ref object
            i, m: int
            val, orig: string
            single: bool

    proc aobj(s: string): Cobj =
        new (result)
        result.val = s.toLower()

    proc fobj(s: string): Cobj =
        new(result)
        result.orig = s # [TODO] Duplicate below?
        result.val = s.toLower()
        result.m = s.endsWith("=*").int
        if s[1] != C_HYPHEN:
            result.orig = s  # [TODO] Duplicate above?
            result.single = true

    proc asort(a, b: Cobj): int =
        if a.val != b.val:
            if a.val < b.val: result = -1
            else: result = 1
        else: result = 0

        if result == 0 and a.single and b.single:
            if a.orig < b.orig: result = 1
            else: result = 0

    # compare function: Gives precedence to flags ending with '=*' else
    #     falls back to sorting alphabetically.
    #
    # @param  {string} a - Item a.
    # @param  {string} b - Item b.
    # @return {number} - Sort result.
    #
    # Give multi-flags higher sorting precedence:
    # @resource [https://stackoverflow.com/a/9604891]
    # @resource [https://stackoverflow.com/a/24292023]
    # @resource [http://www.javascripttutorial.net/javascript-array-sort/]
    # let sort = (a, b) => ~~b.endsWith("=*") - ~~a.endsWith("=*") || asort(a, b)
    proc fsort(a, b: Cobj): int =
        result = b.m - a.m
        if result == 0: result = asort(a, b)

    # Uses map sorting to reduce redundant preprocessing on array items.
    #
    # @param  {array} A - The source array.
    # @param  {function} comp - The comparator function to use.
    # @return {array} - The resulted sorted array.
    #
    # @resource [https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/sort]
    proc mapsort(A: seq[string], comp: proc, cobj_type: string): seq[string] =
        var T: seq[Cobj] = @[] # Temp array.
        var R: seq[string] = @[] # Result array.
        var obj: Cobj
        for i, a in A:
            if cobj_type == "aobj": obj = aobj(a)
            else: obj = fobj(a)
            obj.i = i
            T.add(obj)
        T.sort(comp)
        for i in 0 ..< T.len: R.insert(@[A[T[i].i]], i)
        return R

    # Removes first command in command chain. However, when command name
    # is not the main command in (i.e. in a test file) just remove the
    # first command name in the chain.
    #
    # @param  {string} command - The command chain.
    # @return {string} - Modified chain.
    proc rm_fcmd(chain: string): string =
        result = chain.replace(r)

#     let lastn = (list, offset = -1) => list[list.length + offset];
#     let strfrmpts = (s, start, end) => s.substring(start, end + 1);

    proc get_cmdstr(start, stop: int): string =
        var output: seq[string] = @[]
        const allowed_tk_types = ["tkSTR", "tkDLS"]
        for tid in countup(start, stop):
            if S.lexerdata.tokens[tid].kind in allowed_tk_types:
                if output.len > 0 and output[^1] == "$":
                    output[^1] = "$" & tkstr(tid)
                else: output.add(tkstr(tid))

        return "$(" & output.join(",") & ")"


    proc processflags(
        gid: int, chain: string,
        flags: seq[Flag],
        queue_flags: var OrderedTable[string, int],
        recunion: bool = false,
        recalias: bool = false) =

        var unions: seq[Flag] = @[]

        for flg in flags:
            let tid = flg.tid
            let assignment = tkstr(flg.assignment)
            let boolean = tkstr(flg.boolean)
            let alias = tkstr(flg.alias)
            var flag = tkstr(tid)
            let ismulti = tkstr(flg.multi)
            let union = (flg.union != -1)
            let values = flg.values
            let kind = tokens[tid].kind

            if alias.len > 0 and not recalias:
                processflags(gid, chain, @[flg], queue_flags,
                    recunion = false, recalias = true)

            # Skip union logic on recursion.
            if not recalias and kind != "tkKYW" and not recunion:
                if union:
                    unions.add(flg)
                    continue
                elif unions.len > 0:
                    for i in countup(0, unions.high):
                        unions[i].values = values
                        processflags(gid, chain, @[unions[i]], queue_flags,
                            recunion = true, recalias = false)
                    unions.setLen(0)

            if recalias:
                oContexts[chain]["{" & flag.replace(re"^-*", "") & "|" & alias & "}"] = 1
                flag = "-" & alias

            if kind == "tkKYW":
                if values.len > 0 and flag != "exclude":
                    var value = ""
                    if values[0].len == 1:
                        value = tkstr(values[0][0]).replace(re_space, "")
                        if flag == "context":
                            value = value[1 .. ^2]
                    else:
                        value = get_cmdstr(values[0][1] + 1, values[0][2])


                    if flag == "default": oDefaults[chain][value] = 1
                    elif flag == "filedir": oFiledirs[chain][value] = 1
                    elif flag == "context": oContexts[chain][value] = 1

                continue

            # Flag with values: build each flag + value.
            if values.len > 0:
                # Baseflag: add multi-flag indicator?
                # Add base flag to Set (adds '--flag=' or '--flag=*').
                queue_flags[flag & "=" & (if ismulti.len > 0: "*" else: "")] = 1
                let mflag = flag & "=" & (if ismulti.len > 0: "" else: "*")
                if mflag in queue_flags: queue_flags.del(mflag)

                for value in values:
                    if value.len == 1: # Single
                        queue_flags[flag & assignment & tkstr(value[0])] = 1
                    else: # Command-string
                        let cmdstr = get_cmdstr(value[1] + 1, value[2])
                        queue_flags[flag & assignment & cmdstr] = 1
            else:
                if ismulti.len == 0:
                    if boolean.len > 0: queue_flags[flag & "?"] = 1
                    elif assignment.len > 0: queue_flags[flag & "="] = 1
                    else: queue_flags[flag] = 1
                else:
                    queue_flags[flag & "=*"] = 1
                    queue_flags[flag & "="] = 1

    proc populate_keywords(chain: string) =
        for i in countup(0, 2):
            if chain notin oKeywords[i]:
                oKeywords[i][chain] = initOrderedTable[string, int]()

    proc populate_chain_flags(gid: int, chain: string, container: var OrderedTable[string, int]) =

        if chain notin excludes:
            processflags(gid, chain, ubflags, container,
                recunion = false, recalias = false)

        if chain notin oSets:
            oSets[chain] = container
        else:
            for k, v in container.mpairs:
                oSets[chain][k] = v

    proc build_kwstr(kwtype: string,
        container: OrderedTableRef[string, OrderedTable[string, int]]): string =

        var output: seq[string] = @[]
        var chains: seq[string] = @[]
        for chain in container.keys:
            if container[chain].len > 0:
                chains.add(chain)
        chains = mapsort(chains, asort, "aobj")
        let cl = chains.len - 1
        for i in countup(0, chains.high):
            let chain = chains[i]
            # toSeq: [https://stackoverflow.com/q/70240040]
            let values = toSeq(container[chain].keys)
            let value = (if kwtype != "context": values[^1] else: '"' & values.join(";") & '"')
            output.add(rm_fcmd(chain) & " " & kwtype & " " & value)
            if i < cl: output.add("\n")

        return (if output.len > 0: "\n\n" & output.join("") else: "")

    proc make_chains(ccids: ref seq[int]): seq[string] =
        var slots: seq[string] = @[]
        var chains: seq[string] = @[]
        var groups: seq[seq[string]] = @[]
        var grouping = false

        for i in countup(0, ccids[].high):
            let cid = ccids[][i]

            if cid == -1: grouping = not grouping

            if not grouping and cid != -1:
                slots.add(tkstr(cid))
            elif grouping:
                if cid == -1:
                    slots.add("?")
                    groups.add(@[])
                else: groups[^1].add(tkstr(cid))

        let tstr = slots.join(".")

        for i in countup(0, groups.high):
            let group = groups[i]

            if chains.len == 0:
                for command in group:
                    # Why must '$' be used here?
                    chains.add(tstr.replace("?", $command))
            else:
                var tmp_cmds: seq[string] = @[]
                for chain in chains:
                    for command in group:
                        let command = group[i]
                        # Why must '$' be used here?
                        tmp_cmds.add(chain.replace("?", $command));
                chains = tmp_cmds

        if groups.len == 0: chains.add(tstr)

        return chains

    # Start building acmap contents. -------------------------------------------

    for i in countup(0, cchains.high):
        let group = cchains[i]

        for ccids in group:
            for chain in make_chains(ccids):

                if chain == "*": continue

                var container = initOrderedTable[string, int]()
                populate_keywords(chain)
                processflags(i, chain, flags.getOrDefault($i, @[]), container)
                populate_chain_flags(i, chain, container)

                # Create missing parent chains.
                var commands = chain.split(re"(?<!\\)\.")
                discard commands.pop() # Remove last command (already made).
                var j = commands.high
                while j > -1:
                    let rchain = commands.join("."); # Remainder chain.

                    populate_keywords(rchain)
                    if rchain notin oSets:
                        var container = initOrderedTable[string, int]()
                        populate_chain_flags(i, rchain, container)

                    discard commands.pop() # Remove last command.
                    dec(j)

    defaults = build_kwstr("default", oDefaults)
    filedirs = build_kwstr("filedir", oFiledirs)
    contexts = build_kwstr("context", oContexts)

    # Populate settings object.
    for setting in settings:
        let name = (tkstr(setting[][0]))[1 .. ^1]
        if name == "test": oTests.add(tkstr(setting[][2]).replace(re_space_cl, ";"))
        else: oSettings[name] = (if setting[].len > 1: tkstr(setting[][2]) else: "")

    # Build settings contents.
    settings_count = oSettings.len
    settings_count -= 1
    for setting, value in oSettings.mpairs:
        config &= "@" & setting & " = " & value
        if settings_count > 0: config &= "\n"
        settings_count -= 1

    let placehold = oSettings.hasKey("placehold") and oSettings["placehold"] == "true"
    for key, `set` in oSets.pairs:
        var flags = mapsort(toSeq(`set`.keys), fsort, "fobj").join("|")
        if flags.len == 0: flags = "--"

        # Note: Placehold long flag sets to reduce the file's chars.
        # When flag set is needed its placeholder file can be read.
        if placehold and flags.len >= 100:
            if not omd5Hashes.hasKey(flags):
                let md5hash = getMD5(flags)[26 .. 31]
                oPlaceholders[md5hash] = flags
                omd5Hashes[flags] = md5hash
                flags = "--p#" & md5hash
            else: flags = "--p#" & omd5Hashes[flags]

        let row = rm_fcmd(key) & " " & flags

        # Remove multiple ' --' command chains. Shouldn't be the
        # case but happens when multiple main commands are used.
        if row == " --" and not has_root: has_root = true
        elif row == " --" and has_root: continue

        acdef_lines.add(row)

    # If contents exist, add newline after header.
    # let sheader = if header != "": header[0 .. ^2] else: ""
    let sheader = strutils.strip(header, leading=false)
    let acdef_contents = mapsort(acdef_lines, asort, "aobj").join("\n")
    acdef = if acdef_contents != "": header & acdef_contents else: sheader
    config = if config != "": header & config else: sheader

    let tests = if oTests.len > 0:
        "#!/bin/bash\n\n" & header & "tests=(\n" & oTests.join("\n") & "\n)"
        else: ""

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

    data.acdef = acdef
    data.config = config
    data.keywords = defaults
    data.filedirs = filedirs
    data.contexts = contexts
    data.placeholders = oPlaceholders
    data.tests = tests
    result = data
