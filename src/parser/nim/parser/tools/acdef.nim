import std/[md5, algorithm, sequtils, unicode, re]
import std/[strutils, times, strtabs, sets, tables]

import ../helpers/types

# Generate .acdef, .config.acdef file contents.
#
# @param  {object} S - State object.
# @param  {string} cmdname - Name of <command>.acdef being parsed.
# @return {object} - Object containing acdef, config, and keywords contents.
proc acdef*(S: State, cmdname: string): tuple =
    var oSets = initOrderedTable[string, HashSet[string]]()
    var oGroups = initOrderedTable[int, Table[string, seq[Node]]]()
    var oDefaults = newStringTable()
    var oFiledirs = newStringTable()
    var oContexts = newStringTable()
    var oSettings = initOrderedTable[string, string]()
    var settings_count = 0
    var oPlaceholders = newStringTable()
    var omd5Hashes = newStringTable()
    var count = 0
    var acdef = ""
    var acdef_lines: seq[string] = @[]
    var config = ""
    var defaults = ""
    var filedirs = ""
    var contexts = ""
    var has_root = false

    # Escape '+' chars in commands.
    let rcmdname = cmdname.replace(re"\+", "\\+")
    var r = re("^(" & rcmdname & "|[-_a-zA-Z0-9]+)")

    let date = getTime()
    let datestring = date.format("ddd MMM dd yyyy HH:mm:ss")
    let timestamp = date.toUnix()
    let ctime = datestring & " (" & $timestamp & ")"
    var header = "# DON'T EDIT FILE —— GENERATED: " & ctime & "\n\n"
    if S.args.test: header = ""

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
        result.orig = s
        result.val = s.toLower()
        result.m = s.endsWith("=*").int
        if s[1] != '-':
            result.orig = s
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

    # Group commands with their flags.

    var last = ""
    var rN: Node # Reference node.
    var dN: seq[Node] = @[] # Delimited flag nodes.
    var xN = S.tables.tree["nodes"]
    var wildcard = false
    var wc_flg: seq[Node] = @[]
    var wc_exc = initHashSet[string]()
    const ftypes = toHashSet(["FLAG", "OPTION"])
    const types = toHashSet(["SETTING", "COMMAND", "FLAG", "OPTION"])

    # Contain missing parent command chains in their own group.
    oGroups[-1] = {"commands": @[], "flags": @[], "_": @[node(S, nkCommand)]}.toTable

    var i = 0; var l = xN.len; while i < l:
        let N = xN[i]
        let `type` = N.node

        if not types.contains(`type`): inc(i); continue

        # Check whether new group must be started.
        if last != "":
            if last == "COMMAND":
                if `type` == "COMMAND" and rN.delimiter.value == "": inc(count)
            elif ftypes.contains(last):
                if not ftypes.contains(`type`): inc(count)

            last = ""

        case (`type`):
            of "COMMAND":

                # Handle wildcard node.
                if N.command.value == "*":
                    wildcard = true
                    inc(i); continue
                else: wildcard = false

                # Store command in current group.
                if count notin oGroups:
                    oGroups[count] = {"commands": @[N], "flags": @[]}.toTable
                else: oGroups[count]["commands"].add(N)

                let cval = N.command.value
                if cval notin oSets:
                    oSets[cval] = initHashSet[string]()

                    # Create missing parent chains.
                    var commands = cval.split(re"(?<!\\)\.")
                    discard commands.pop() # Remove last command (already made).
                    var i = commands.high
                    while i > -1:
                        let rchain = commands.join(".") # Remainder chain.
                        if not oSets.hasKey(rchain):
                            var mN = node(S, nkCommand)
                            mN.command.value = rchain
                            oGroups[-1]["commands"].add(mN)
                            oSets[rchain] = initHashSet[string]()
                        discard commands.pop() # Remove last command.
                        dec(i)

                last = `type`
                rN = N # Store reference to node.

            of "FLAG":
                let keyword = N.keyword.value

                # Handle wildcard flags.
                if wildcard:
                    if keyword == "exclude": wc_exc.incl(N.value.value[1 .. ^2])
                    else: wc_flg.add(N)
                    inc(i); continue

                # Add values/arguments to delimited flags.
                if N.delimiter.value != "": dN.add(N)
                elif keyword == "": # Skip/ignore keywords.
                    let args = N.args
                    let value = N.value.value
                    for i, tN in dN:
                        var tN = dN[i]
                        tN.args = args
                        tN.value.value = value
                    dN.setLen(0)

                oGroups[count]["flags"].add(N) # Store command in current group.
                last = `type`

            of "OPTION":
                # Add value to last flag in group.
                var fxN = oGroups[count]["flags"]
                oGroups[count]["flags"][fxN.high].args.add(N.value.value)
                last = `type`

            of "SETTING":
                let name = N.name.value
                if name != "test":
                    if not oSettings.hasKey(name): inc(settings_count)
                    oSettings[name] = N.value.value

        inc(i)

    # Populate Sets.

    # Add flags, keywords to respective containers.
    #
    # @param  {array} fxN - The flag nodes.
    # @param  {set} queue_defs - The defaults container.
    # @param  {set} queue_fdir - The filedirs container.
    # @param  {set} queue_ctxs - The contexts container.
    # @param  {set} queue_flags - The flags container.
    # @return - Nothing is returned.
    proc queues(fxN: seq[Node], queue_defs: var OrderedSet[string],
        queue_fdir: var OrderedSet[string], queue_ctxs: var OrderedSet[string],
        queue_flags: var HashSet[string]) =
        for fN in fxN:
            let args = fN.args
            let keyword = fN.keyword.value

            # If flag is a default/keyword store it.
            if keyword != "":
                let value = fN.value.value
                if keyword == "default": queue_defs.incl(value)
                elif keyword == "filedir": queue_fdir.incl(value)
                elif keyword == "context":
                    queue_ctxs.incl(value.strip(chars={'"', '\''}))
                continue # defaults don't need to be added to Sets.

            let aval = fN.assignment.value
            let bval = fN.boolean.value
            let flag = fN.hyphens.value & fN.name.value
            let ismulti = fN.multi.value != ""

            # Flag with values: build each flag + value.
            if args.len > 0:
                # Baseflag: add multi-flag indicator?
                # Add base flag to Set (adds '--flag=' or '--flag=*').
                queue_flags.incl(flag & "=" & (if ismulti: "*" else: ""))
                queue_flags.excl(flag & "=" & (if ismulti: "" else: "*"))

                for arg in args: queue_flags.incl(flag & aval & arg)
            else:
                # Boolean flag...
                if bval != "": queue_flags.incl(flag & "?")
                elif not ismulti:
                    if aval != "": queue_flags.incl(flag & "=")
                    else: queue_flags.incl(flag)
                else:
                    if not ismulti:
                        if bval != "": queue_flags.incl(flag & "?")
                        elif aval != "": queue_flags.incl(flag & "=")
                        else: queue_flags.incl(flag)
                    else:
                        queue_flags.incl(flag & "=*")
                        queue_flags.incl(flag & "=")

    for i, group in oGroups.pairs:
        var cxN = group["commands"]
        var fxN = group["flags"]
        var queue_defs: OrderedSet[string]
        var queue_fdir: OrderedSet[string]
        var queue_ctxs: OrderedSet[string]
        var queue_flags: HashSet[string]

        queues(fxN, queue_defs, queue_fdir, queue_ctxs, queue_flags)

        for cN in cxN:
            let value = cN.command.value;

            # Add wildcard flags.
            if wc_flg.len != 0 and not wc_exc.contains(value):
                queues(wc_flg, queue_defs, queue_fdir, queue_ctxs, queue_flags)

            for item in queue_flags.items: oSets[value].incl(item)
            for item in queue_defs.items: oDefaults[value] = item
            for item in queue_fdir.items: oFiledirs[value] = item
            for item in queue_ctxs.items:
                if oContexts.hasKey(value): oContexts[value] &= ";" & item
                else: oContexts[value] = item

    # Generate acdef.

    let placehold = oSettings.hasKey("placehold") and oSettings["placehold"] == "true"
    for command, `set` in oSets.pairs:
        let `set` = oSets[command]
        var flags = "--"

        # If Set has items then it has flags so convert to an array.
        # [https://stackoverflow.com/a/47243199]
        # [https://stackoverflow.com/a/21194765]
        if `set`.len > 0:
            var commands: seq[string] = @[]
            for command in `set`.items: commands.add(command)
            flags = mapsort(commands, fsort, "fobj").join("|")

        # Note: Placehold long flag sets to reduce the file's chars.
        # When flag set is needed its placeholder file can be read.
        if placehold and flags.len >= 100:
            if not omd5Hashes.hasKey(flags):
                let md5hash = getMD5(flags)[26 .. 31]
                oPlaceholders[md5hash] = flags
                omd5Hashes[flags] = md5hash
                flags = "--p#" & md5hash
            else: flags = "--p#" & omd5Hashes[flags]

        let row = rm_fcmd(command) & " " & flags

        # Remove multiple ' --' command chains. Shouldn't be the
        # case but happens when multiple main commands are used.
        if row == " --" and not has_root: has_root = true
        elif row == " --" and has_root: continue

        acdef_lines.add(row)

    # Build defaults contents.
    var deflist: seq[string] = @[]
    for default in oDefaults.keys: deflist.add(default)
    let defs = mapsort(deflist, asort, "aobj")
    let dl = defs.high
    for i, c in defs:
        defaults &= rm_fcmd(c) & " default " & oDefaults[c]
        if i < dl: defaults &= "\n"
    if defaults != "": defaults = "\n\n" & defaults

    # Build filedir contents.
    var fdirlist: seq[string] = @[]
    for filedir in oFiledirs.keys: fdirlist.add(filedir)
    let fdirs = mapsort(fdirlist, asort, "aobj")
    let fl = fdirs.high
    for i, c in fdirs:
        filedirs &= rm_fcmd(c) & " filedir " & oFiledirs[c]
        if i < fl: filedirs &= "\n"
    if filedirs != "": filedirs = "\n\n" & filedirs

    # Build contexts contents.
    var ctxlist: seq[string] = @[]
    for context in oContexts.keys: ctxlist.add(context)
    let ctxs = mapsort(ctxlist, asort, "aobj")
    let cl = ctxs.high
    for i, c in ctxs:
        contexts &= rm_fcmd(c) & " context \"" & oContexts[c] & "\""
        if i < cl: contexts &= "\n"
    if contexts != "": contexts = "\n\n" & contexts

    # Build settings contents.
    dec(settings_count)
    for setting in oSettings.keys:
        config &= "@" & setting & " = " & oSettings[setting]
        if settings_count != 0: config &= "\n"
        dec(settings_count)

    # If contents exist, add newline after header.
    let sheader = if header != "": header[0 .. ^2] else: ""
    let acdef_contents = mapsort(acdef_lines, asort, "aobj").join("\n")
    acdef = if acdef_contents != "": header & acdef_contents else: sheader
    config = if config != "": header & config else: sheader

    let tests = if S.tests.len != 0:
        "#!/bin/bash\n\n" & header & "tests=(\n" & S.tests.join("\n") & "\n)"
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
