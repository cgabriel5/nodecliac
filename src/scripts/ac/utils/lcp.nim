#!/usr/bin/env nim

from algorithm import sort
from tables import `$`, add, del, len, `[]`, `[]=`, pairs, Table,
    hasKey, initTable, initOrderedTable
from strutils import startsWith

# Finds all common prefixes in a list of strings.
#
# @param  {array} strs - The list of strings.
# @return {array} - The found/collected prefixes.
#
# @resource [https://stackoverflow.com/q/6634480]
# @resource [https://stackoverflow.com/a/6634498]
# @resource [https://stackoverflow.com/a/1917041]
# @resource [https://softwareengineering.stackexchange.com/q/262242]
# @resource [https://stackoverflow.com/q/11397137]
proc lcp*(
            strs: var seq[string],
            charloop_startindex = 0, # Index where char loop will start at.
            min_frqz_prefix_len = 1, # Min length string should be to store frqz.
            min_prefix_len = 1, # Min length prefixes should be.
            min_frqz_count = 2, # Min frqz required to be considered a prefix.
            min_src_list_size = 0, # Min size source array must be to proceed.
            # [https://nim-lang.org/docs/tut1.html#advanced-types-open-arrays]
            char_break_points: openArray[char] = [], # Hitting these chars will break the inner loop.
            prepend = "", # Prefix to prepend to final prefix.
            append = "" # Suffix to append to final prefix.
    ): auto =
    let l = strs.len
    var frqz = initOrderedTable[string, int]()
    var indices = initTable[string, Table[int, bool]]()
    var aindices = initTable[string, seq[int]]()
    var prxs: seq[string] = @[]
    var xids = initTable[int, bool]()
    var r: tuple[prefixes: seq[string], indices: Table[int, bool]]

    # Prepend/append prefix/suffix to string.
    #
    # @param  {string} s - The string to modidy.
    # @return {string} - The string with prepended/appended strings.
    proc decorate(s: string): string =
        return prepend & s & append

    # If char breakpoints are provided create lookup table.
    var char_bps = initTable[char, bool]()
    for chr in char_break_points: char_bps[chr] = true

    if l < min_src_list_size:
        r = (prefixes: prxs, indices: xids)
        return r

    # Short-circuits.
    if l <= 2:
        # Get string from startpoint to any character  breakpoints.
        #
        # @param  {string} s - String to loop.
        # @return {string} - Resulting string from any trimming/clipping.
        proc stringloop(s: string): string =
            var prefix = ""
            for i in countup(charloop_startindex, s.len - 1):
                let chr = s[i]
                if char_bps.hasKey(chr): break
                prefix &= $chr
            return decorate(prefix)

        case (l):
            of 0:
                r = (prefixes: prxs, indices: xids)
                return r
            of 1:
                xids[0] = false
                r = (prefixes: @[stringloop(strs[0])], indices: xids)
                return r
            of 2:
                if strs[0] == strs[1]:
                    xids[0] = false
                    xids[1] = true
                    r = (prefixes: @[stringloop(strs[0])], indices: xids)
                    return r

                # [https://stackoverflow.com/a/35838357]
                strs.sort(
                    proc (a, b: string): int =
                        if b.len < a.len: -1 else: 1
                )
                let first = strs[0]
                let last = strs[1]
                let lastlen = last.len
                var ep = charloop_startindex # Endpoint.
                while ep < lastlen and first[ep] == last[ep]: inc(ep)
                let prefix = first.substr(0, ep - 1)

                let isprefix_empty = prefix != ""
                let isfirst_prefixed = first.startsWith(prefix)
                if isprefix_empty:
                    xids[0] = not isfirst_prefixed
                    xids[1] = isfirst_prefixed
                r = (prefixes: (if isprefix_empty:  @[stringloop(prefix)] else: @[]), indices: xids)
                return r

            else: discard

    # Loop over each completion string.
    for i, str in strs:
        var prefix = ""

        # Loop over each char in string.
        for j in countup(charloop_startindex, str.len - 1):
            let chr = str[j]
            prefix &= $chr

            if char_bps.hasKey(chr): break

            # Store if min length satisfied.
            if prefix.len >= min_frqz_prefix_len:
                if not frqz.hasKey(prefix): frqz[prefix] = 0
                inc(frqz[prefix])

                if not indices.hasKey(prefix): indices[prefix] = initTable[int, bool]()
                indices[prefix][i] = true

                if not aindices.hasKey(prefix): aindices[prefix] = @[]
                aindices[prefix].add(i)

    var aprefixes: seq[string] = @[]
    var tprefixes = initOrderedTable[string, int]()

    # Loop over each prefix in frequency table.
    for str, count in frqz.pairs:
        block loop1:
            if not tprefixes.hasKey(str) and count >= 2:
                let prevkey = str[0 .. ^2]
                let prevcount = if tprefixes.hasKey(prevkey): tprefixes[prevkey] else: 0

                if prevcount > count: continue

                if aprefixes.len != 0:
                    for prefix in aprefixes:
                        if str.startsWith(prefix) and tprefixes[prefix] > count:
                            break loop1

                if prevcount != 0:
                    discard aprefixes.pop()
                    tprefixes.del(prevkey)

                aprefixes.add(str)
                tprefixes[str] = count

    # Filter prefixes based on length and frqz count.
    for prefix in aprefixes:
        if prefix.len > min_prefix_len and tprefixes[prefix] >= min_frqz_count:
            for k, v in indices[prefix].pairs:
                xids[k] = if aindices[prefix][0] == k: false else: v
            prxs.add(decorate(prefix))
    r = (prefixes: prxs, indices: xids)
    return r

# # Examples:

# var strs: seq[string] = @[]

# strs = @[
#     "Call Mike and schedule meeting.",
#     "Call Lisa",
#     # "Cat",
#     "Call Adam and ask for quote.",
#     "Implement new class for iPhone project",
#     "Implement new class for Rails controller",
#     "Buy groceries"
#     # "Buy groceries"
# ]
# echo 13, " ", lcp(strs)

# strs = @["--hintUser=", "--hintUser=", "--hintUser="]
# echo -1, " ", lcp(
#     strs,
#     charloop_startindex = 2,
#     min_frqz_prefix_len = 2,
#     min_prefix_len = 3,
#     min_frqz_count = 3,
#     char_break_points = ['='],
#     prepend = "--",
#     append = "..."
# )

# strs = @[
#     "--app=",
#     "--assertions=",
#     "--boundChecks=",
#     "--checks=",
#     "--cincludes=",
#     "--clib=",
#     "--clibdir=",
#     "--colors=",
#     "--compileOnly=",
#     "--cppCompileToNamespace=",
#     "--cpu=",
#     "--debugger=",
#     "--debuginfo=",
#     "--define=",
#     "--docInternal ",
#     "--docSeeSrcUrl=",
#     "--dynlibOverride=",
#     "--dynlibOverrideAll ",
#     "--embedsrc=",
#     "--errorMax=",
#     "--excessiveStackTrace=",
#     "--excludePath=",
#     "--expandMacro=",
#     "--experimental=",
#     "--fieldChecks=",
#     "--floatChecks=",
#     "--forceBuild=",
#     "--fullhelp ",
#     "--gc=",
#     "--genDeps=",
#     "--genScript=",
#     "--help ",
#     "--hintCC=",
#     "--hintCodeBegin=",
#     "--hintCodeEnd=",
#     "--hintCondTrue=",
#     "--hintConf=",
#     "--hintConvFromXtoItselfNotNeeded=",
#     "--hintConvToBaseNotNeeded=",
#     "--hintDependency=",
#     "--hintExec=",
#     "--hintExprAlwaysX=",
#     "--hintExtendedContext=",
#     "--hintGCStats=",
#     "--hintGlobalVar=",
#     "--hintLineTooLong=",
#     "--hintLink=",
#     "--hintName=",
#     "--hintPath=",
#     "--hintPattern=",
#     "--hintPerformance=",
#     "--hintProcessing=",
#     "--hintQuitCalled=",
#     "--hints=",
#     "--hintSource=",
#     "--hintStackTrace=",
#     "--hintSuccess=",
#     "--hintSuccessX=",
#     "--hintUser=",
#     "--hintUserRaw=",
#     "--hintXDeclaredButNotUsed=",
#     "--hotCodeReloading=",
#     "--implicitStatic=",
#     "--import=",
#     "--include=",
#     "--incremental=",
#     "--index=",
#     "--infChecks=",
#     "--laxStrings=",
#     "--legacy=",
#     "--lib=",
#     "--lineDir=",
#     "--lineTrace=",
#     "--listCmd ",
#     "--listFullPaths=",
#     "--memTracker=",
#     "--multimethods=",
#     "--nanChecks=",
#     "--newruntime ",
#     "--nilChecks=",
#     "--nilseqs=",
#     "--NimblePath=",
#     "--nimcache=",
#     "--noCppExceptions ",
#     "--noLinking=",
#     "--noMain=",
#     "--noNimblePath ",
#     "--objChecks=",
#     "--oldast=",
#     "--oldNewlines=",
#     "--opt=",
#     "--os=",
#     "--out=",
#     "--outdir=",
#     "--overflowChecks=",
#     "--parallelBuild=",
#     "--passC=",
#     "--passL=",
#     "--path=",
#     "--profiler=",
#     "--project ",
#     "--putenv=",
#     "--rangeChecks=",
#     "--refChecks=",
#     "--run ",
#     "--showAllMismatches=",
#     "--skipCfg=",
#     "--skipParentCfg=",
#     "--skipProjCfg=",
#     "--skipUserCfg=",
#     "--stackTrace=",
#     "--stdout=",
#     "--styleCheck=",
#     "--taintMode=",
#     "--threadanalysis=",
#     "--threads=",
#     "--tlsEmulation=",
#     "--trmacros=",
#     "--undef=",
#     "--useVersion=",
#     "--verbosity=",
#     "--version ",
#     "--warningCannotOpenFile=",
#     "--warningConfigDeprecated=",
#     "--warningDeprecated=",
#     "--warningEachIdentIsTuple=",
#     "--warningOctalEscape=",
#     "--warnings=",
#     "--warningSmallLshouldNotBeUsed=",
#     "--warningUser="
# ]
# echo 1, " ", lcp(
#     strs,
#     charloop_startindex = 2,
#     min_frqz_prefix_len = 2,
#     min_prefix_len = 3,
#     min_frqz_count = 3,
#     char_break_points = ['='],
#     prepend = "--",
#     append = "..."
# )

# strs = @[
#     "--app=",
#     "--assertions=",
#     "--boundChecks=",
#     "--checks=",
#     "--cincludes=",
#     "--clib=",
#     "--clibdir=",
#     "--colors="
# ]
# echo 2, " ", lcp(
#     strs,
#     charloop_startindex = 2,
#     min_frqz_prefix_len = 2,
#     min_prefix_len = 3,
#     min_frqz_count = 3,
#     char_break_points = ['='],
#     prepend = "--",
#     append = "..."
# )

# strs = @[
#     "--warningCannotOpenFile",
#     "--warningConfigDeprecated",
#     "--warningDeprecated",
#     "--warningEachIdentIsTuple",
#     "--warningOctalEscape",
#     "--warnings",
#     "--warningSmallLshouldNotBeUsed",
#     "--warningUser"
# ]
# echo 3, " ", lcp(
#     strs,
#     charloop_startindex = 2,
#     min_frqz_prefix_len = 2,
#     min_prefix_len = 3,
#     min_frqz_count = 3,
#     char_break_points = ['='],
#     prepend = "--",
#     append = "..."
# )

# strs = @[
#     "--skipCfg=",
#     "--skipParentCfg=",
#     "--skipProjCfg=",
#     "--skipUserCfg="
# ]
# echo 4, " ", lcp(
#     strs,
#     charloop_startindex = 2,
#     min_frqz_prefix_len = 2,
#     min_prefix_len = 3,
#     min_frqz_count = 3,
#     char_break_points = ['='],
#     prepend = "--",
#     append = "..."
# )

# strs = @[
#     "--hintCC=",
#     "--hintCodeBegin=",
#     "--hintCodeEnd=",
#     "--hintCondTrue=",
#     "--hintConf=",
#     "--hintConvFromXtoItselfNotNeeded=",
#     "--hintConvToBaseNotNeeded=",
#     "--hintDependency=",
#     "--hintExec=",
#     "--hintExprAlwaysX=",
#     "--hintExtendedContext=",
#     "--hintGCStats=",
#     "--hintGlobalVar=",
#     "--hintLineTooLong=",
#     "--hintLink=",
#     "--hintName=",
#     "--hintPath=",
#     "--hintPattern=",
#     "--hintPerformance=",
#     "--hintProcessing=",
#     "--hintQuitCalled=",
#     "--hints=",
#     "--hintSource=",
#     "--hintStackTrace=",
#     "--hintSuccess=",
#     "--hintSuccessX=",
#     "--hintUser=",
#     "--hintUserRaw="
# ]
# echo 5, " ", lcp(
#     strs,
#     charloop_startindex = 2,
#     min_frqz_prefix_len = 2,
#     min_prefix_len = 3,
#     min_frqz_count = 3,
#     char_break_points = ['='],
#     prepend = "--",
#     append = "..."
# )

# strs = @[
#     "--warnings=",
#     "--warningCannotOpenFile=",
#     "--warningXonfigDeprecated=",
#     "--warningPofigApple=",
#     "--warningCofigApple=",
#     "--warningCofigApple=",
#     "--warningCofigApple=",
#     "--warningCofigApple=",
#     "--warningCofigApple=",
#     "--warningCofigApple=",
#     "--warningCofgTest="
# ]
# echo 6, " ", lcp(
#     strs,
#     charloop_startindex = 2,
#     min_frqz_prefix_len = 2,
#     min_prefix_len = 3,
#     min_frqz_count = 3,
#     char_break_points = ['='],
#     prepend = "--",
#     append = "..."
# )

# strs = @["--warnings=", "--warningCannotOpenFile="]
# echo 7, " ", lcp(
#     strs,
#     charloop_startindex = 2,
#     min_frqz_prefix_len = 2,
#     min_prefix_len = 3,
#     min_frqz_count = 3,
#     char_break_points = ['='],
#     prepend = "--",
#     append = "..."
# )

# strs = @["--warnings="]
# echo 8, " ", lcp(
#     strs,
#     charloop_startindex = 2,
#     min_frqz_prefix_len = 2,
#     min_prefix_len = 3,
#     min_frqz_count = 3,
#     char_break_points = ['='],
#     prepend = "--",
#     append = "..."
# )

# strs = @[
#     "--hintCC=",
#     "--hintCodeBegin=",
#     "--hintCodeEnd=",
#     "--hintCondTrue=",
#     "--hintConf=",
#     "--hintConvFromXtoItselfNotNeeded=",
#     "--hintConvToBaseNotNeeded=",
#     "--hintDependency=",
#     "--hintExec=",
#     "--hintExprAlwaysX=",
#     "--hintExtendedContext=",
#     "--hintGCStats=",
#     "--hintGlobalVar=",
#     "--hintLineTooLong=",
#     "--hintLink=",
#     "--hintName=",
#     "--hintPath=",
#     "--hintPattern=",
#     "--hintPerformance=",
#     "--hintProcessing=",
#     "--hintQuitCalled=",
#     "--hints=",
#     "--hintSource=",
#     "--hintStackTrace=",
#     "--hintSuccess=",
#     "--hintSuccessX=",
#     "--hintUser=",
#     "--hintUserRaw=",
#     "--hintXDeclaredButNotUsed="
# ]
# echo 9, " ", lcp(
#     strs,
#     charloop_startindex = 2,
#     min_frqz_prefix_len = 2,
#     min_prefix_len = 3,
#     min_frqz_count = 3,
#     char_break_points = ['='],
#     prepend = "--",
#     append = "..."
# )

# strs = @["--hintCC="]
# echo 10, " ", lcp(
#     strs,
#     charloop_startindex = 2,
#     min_frqz_prefix_len = 2,
#     min_prefix_len = 3,
#     min_frqz_count = 3,
#     char_break_points = ['='],
#     prepend = "--",
#     append = "..."
# )

# strs = @["--hintUser=", "--hintUserRaw=", "--hintXDeclaredButNotUsed="]
# echo 11, " ", lcp(
#     strs,
#     charloop_startindex = 2,
#     min_frqz_prefix_len = 2,
#     min_prefix_len = 3,
#     min_frqz_count = 3,
#     char_break_points = ['='],
#     prepend = "--",
#     append = "..."
# )

# strs = @[
#     "--hintSuccessX=",
#     "--hintUser=",
#     "--hintUserRaw=",
#     "--hintXDeclaredButNotUsed="
# ]
# echo 12, " ", lcp(
#     strs,
#     charloop_startindex = 2,
#     min_frqz_prefix_len = 2,
#     min_prefix_len = 3,
#     min_frqz_count = 3,
#     char_break_points = ['='],
#     prepend = "--",
#     append = "..."
# )

# strs = @[
#     "Call Mike and schedule meeting.",
#     "Call Lisa",
#     "Call Adam and ask for quote.",
#     "Implement new class for iPhone project",
#     "Implement new class for Rails controller",
#     "Buy groceries"
# ]
# echo 13, " ", lcp(strs)

# strs = @["interspecies", "interstelar", "interstate"]
# echo 14, lcp(strs) # "inters"
# strs = @["throne", "throne"]
# echo 15, lcp(strs) # "throne"
# strs = @["throne", "dungeon"]
# echo 16, lcp(strs) # ""
# strs = @["cheese"]
# echo 17, lcp(strs) # "cheese"
# strs = @[]
# echo 18, lcp(strs) # ""
# strs = @["prefix", "suffix"]
# echo 19, lcp(strs) # ""
