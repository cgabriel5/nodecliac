#!/usr/bin/env nim

from algorithm import sort
from tables import
    `$`,
    add,
    del,
    len,
    keys,
    `[]`,
    `[]=`,
    pairs,
    Table,
    hasKey,
    initTable,
    initOrderedTable
from strutils import startsWith # , cmpIgnoreCase

# Finds all common prefixes in a list of strings.
#
# @param  {array} strs - The list of strings.
# @return {array} - The found/collected prefixes.
#
# @resource [https://www.perlmonks.org/?node_id=274114]
# @resource [https://stackoverflow.com/q/6634480]
# @resource [https://stackoverflow.com/a/6634498]
# @resource [https://stackoverflow.com/a/35588015]
# @resource [https://stackoverflow.com/a/35838357]
# @resource [https://stackoverflow.com/a/1917041]
# @resource [https://davidwells.io/snippets/traverse-object-unknown-size-javascript]
# @resource [https://jonlabelle.com/snippets/view/javascript/calculate-mean-median-mode-and-range-in-javascript]
# @resource [https://rosettacode.org/wiki/Higher-order_functions#Nim]
proc lcp(
            # Names/positional args: [https://nim-lang.org/docs/manual.html#procedures]
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
    # Vars.
    let l = strs.len
    var frqz = initOrderedTable[string, int]() # Frequency of prefixes.
    # Track indices of strings containing any found prefixes.
    var indices = initTable[string, Table[int, bool]]()
    var aindices = initTable[string, seq[int]]()
    # var frqz = initTable[string, int]() # Frequency of prefixes.
    var prefixes: seq[string] = @[] # Final collection of found prefixes.

    # Final result tuple and its sequence values.
    var prxs: seq[string] = @[]
    var xids = initTable[int, bool]()
    var r: tuple[prefixes: seq[string], indices: Table[int, bool]]

     # Prepend/append provided prefix/suffix to string.
     #
     # @param  {string} s - The string to modidy.
     # @return {string} - The string with prepended/appended strings.
    proc decorate(s: string): string =
        return prepend & s & append

    # If char breakpoints are provided turn into a lookup table.
    var char_bps = initTable[char, bool]()
    for chr in char_break_points: char_bps[chr] = true

    # If source array is not the min size then short-circuit.
    if l < min_src_list_size:
        r = (prefixes: prxs, indices: xids)
        return r

    # If array size is <= 2 strings use one of the following short-circuit methods.
    if l <= 2:
         # Quick loop to get string from provided startpoint and end at
         #     any provided character breakpoints.
         #
         # @param  {string} s - The string to loop.
         # @return {string} - The resulting string from any trimming/clipping.
         #
        proc stringloop(s: string): string =
            var prefix = ""
            for i in countup(charloop_startindex, s.len - 1):
                let chr = s[i] # Cache current loop item.
                if char_bps.hasKey(chr): break # Stop loop if breakpoint char is hit.
                prefix &= $chr # Gradually build prefix.
            return decorate(prefix)

        case (l):
            of 0:
                # If source array is empty return empty array.
                r = (prefixes: prxs, indices: xids)
                return r
            of 1:
                # If only a single string is in array return that string.
                xids[0] = false # Add string index to table.
                r = (prefixes: @[stringloop(strs[0])], indices: xids)
                return r
            of 2: # If 2 strings exists...
                # If strings match then return string...
                if strs[0] == strs[1]:
                    xids[0] = false # Add string indices to table.
                    xids[1] = true # Add string indices to table.
                    r = (prefixes: @[stringloop(strs[0])], indices: xids)
                    return r

                # Else use start/end-point method: [https://stackoverflow.com/a/35838357]
                # to get the prefix between the two strings.
                # Sort: [https://stackoverflow.com/a/10630852]
                # Sorting explained: [https://stackoverflow.com/a/6568100]
                # [https://www.rosettacode.org/wiki/Sort_using_a_custom_comparator#Nim]
                strs.sort(
                    proc (a, b: string): int =
                        if b.len < a.len: -1 else: 1
                ) # Sort strings by length.
                let first = strs[0]
                let last = strs[1]
                let lastlen = last.len
                var ep = charloop_startindex # Index endpoint.
                # Get common prefix between first and last completion items.
                while ep < lastlen and first[ep] == last[ep]: inc(ep)
                # Add common prefix to prefixes array.
                let prefix = first.substr(0, ep - 1)

                # Add string indices to table.
                let isprefix_empty = prefix != ""
                let isfirst_prefixed = first.startsWith(prefix)
                if isprefix_empty:
                    xids[0] = not isfirst_prefixed
                    xids[1] = isfirst_prefixed
                r = (prefixes: (if isprefix_empty:  @[stringloop(prefix)] else: @[]), indices: xids)
                return r

            else: discard # Needed so nim does not complain.

    # Loop over each completion string...
    for i, str in strs:
        var prefix = "" # Gradually build prefix.

        # Loop over each character in string...
        for j in countup(charloop_startindex, str.len - 1):
            let chr = str[j] # Cache current loop item.
            prefix &= $chr # Gradually build prefix each char iteration.

            if char_bps.hasKey(chr): break # Stop loop id breakpoint char is hit.

            # Prefix must be specific length to account for frequency.
            if prefix.len >= min_frqz_prefix_len:
                # If prefix not found in table add to table.
                if not frqz.hasKey(prefix): frqz[prefix] = 0
                inc(frqz[prefix]) # Increment frequency.

                # Track prefix's string index to later filter out items from array.
                if not indices.hasKey(prefix): indices[prefix] = initTable[int, bool]()
                indices[prefix][i] = true # Add index to table

                # Track prefix's string index to later filter out items from array.
                if not aindices.hasKey(prefix): aindices[prefix] = @[]
                aindices[prefix].add(i)

    var aprefixes: seq[string] = @[] # Contain prefixes in array to later check prefix-of-prefixes.
    var tprefixes = initOrderedTable[string, int]() # Contain prefixes in table for later quick lookups.

    # # Note: For languages that don't keep hashes sorted the route would be
    # # to use an array to sort keys.
    # var ofrqz: seq[string] = @[]
    # for k in frqz.keys: ofrqz.add(k)
    # # Sort strings alphabetically.
    # ofrqz.sort(proc (a, b: string): int =
    #     return cmpIgnoreCase(a, b)
    # )

    # Loop over each prefix in the frequency table...
    # block loop1:
    # for str in ofrqz:
    for str, count in frqz.pairs: # Get string and its frequency (count).
        # If prefix doesn't exist in table and its frequency is >= 2 continue...
        # [https://nim-lang.org/docs/manual.html#statements-and-expressions-block-statement]
        block loop1:
            # let count = frqz[str]
            if not tprefixes.hasKey(str) and count >= 2:
                let prevkey = str[0..^2] # Remove (str - last char) if it exists.
                # The previous prefix frequency, else 0 if not existent.
                let prevcount = if tprefixes.hasKey(prevkey): tprefixes[prevkey] else: 0

                # If last entry has a greater count skip this iteration.
                if prevcount > count: continue

                # If any string in array is prefix of the current string, skip string.
                if aprefixes.len != 0:
                    # var has_existing_prefix = false
                    for prefix in aprefixes:
                        # If array string prefixes the string, continue to main loop.
                        if str.startsWith(prefix) and tprefixes[prefix] > count:
                            # has_existing_prefix = true
                            break loop1
                    # if has_existing_prefix: continue

                # When previous count exists remove the preceding prefix from array/table.
                # Empty array: [https://nim-lang.org/docs/strutils.html#isNilOrEmpty%2Cstring]
                if prevcount != 0:
                    discard aprefixes.pop()
                    tprefixes.del(prevkey)

                # Finally, add current string to array/table.
                aprefixes.add(str)
                tprefixes[str] = count

    # Filter prefixes based on prefix length and prefix frequency count.
    for prefix in aprefixes:
        if prefix.len > min_prefix_len and tprefixes[prefix] >= min_frqz_count:
            for k, v in indices[prefix].pairs:
                # Add indices to final table.
                xids[k] = if aindices[prefix][0] == k: false else: v
            prxs.add(decorate(prefix)) # Add prefix to final array.
    r = (prefixes: prxs, indices: xids)
    return r

# Usage examples:

var strs: seq[string] = @[]

strs = @[
    "Call Mike and schedule meeting.",
    "Call Lisa",
    # "Cat",
    "Call Adam and ask for quote.",
    "Implement new class for iPhone project",
    "Implement new class for Rails controller",
    "Buy groceries"
    # "Buy groceries"
]
echo 13, " ", lcp(strs)

strs = @["--hintUser=", "--hintUser=", "--hintUser="]
echo -1, " ", lcp(
    strs,
    charloop_startindex = 2,
    min_frqz_prefix_len = 2,
    min_prefix_len = 3,
    min_frqz_count = 3,
    char_break_points = ['='],
    prepend = "--",
    append = "..."
)

strs = @[
    "--app=",
    "--assertions=",
    "--boundChecks=",
    "--checks=",
    "--cincludes=",
    "--clib=",
    "--clibdir=",
    "--colors=",
    "--compileOnly=",
    "--cppCompileToNamespace=",
    "--cpu=",
    "--debugger=",
    "--debuginfo=",
    "--define=",
    "--docInternal ",
    "--docSeeSrcUrl=",
    "--dynlibOverride=",
    "--dynlibOverrideAll ",
    "--embedsrc=",
    "--errorMax=",
    "--excessiveStackTrace=",
    "--excludePath=",
    "--expandMacro=",
    "--experimental=",
    "--fieldChecks=",
    "--floatChecks=",
    "--forceBuild=",
    "--fullhelp ",
    "--gc=",
    "--genDeps=",
    "--genScript=",
    "--help ",
    "--hintCC=",
    "--hintCodeBegin=",
    "--hintCodeEnd=",
    "--hintCondTrue=",
    "--hintConf=",
    "--hintConvFromXtoItselfNotNeeded=",
    "--hintConvToBaseNotNeeded=",
    "--hintDependency=",
    "--hintExec=",
    "--hintExprAlwaysX=",
    "--hintExtendedContext=",
    "--hintGCStats=",
    "--hintGlobalVar=",
    "--hintLineTooLong=",
    "--hintLink=",
    "--hintName=",
    "--hintPath=",
    "--hintPattern=",
    "--hintPerformance=",
    "--hintProcessing=",
    "--hintQuitCalled=",
    "--hints=",
    "--hintSource=",
    "--hintStackTrace=",
    "--hintSuccess=",
    "--hintSuccessX=",
    "--hintUser=",
    "--hintUserRaw=",
    "--hintXDeclaredButNotUsed=",
    "--hotCodeReloading=",
    "--implicitStatic=",
    "--import=",
    "--include=",
    "--incremental=",
    "--index=",
    "--infChecks=",
    "--laxStrings=",
    "--legacy=",
    "--lib=",
    "--lineDir=",
    "--lineTrace=",
    "--listCmd ",
    "--listFullPaths=",
    "--memTracker=",
    "--multimethods=",
    "--nanChecks=",
    "--newruntime ",
    "--nilChecks=",
    "--nilseqs=",
    "--NimblePath=",
    "--nimcache=",
    "--noCppExceptions ",
    "--noLinking=",
    "--noMain=",
    "--noNimblePath ",
    "--objChecks=",
    "--oldast=",
    "--oldNewlines=",
    "--opt=",
    "--os=",
    "--out=",
    "--outdir=",
    "--overflowChecks=",
    "--parallelBuild=",
    "--passC=",
    "--passL=",
    "--path=",
    "--profiler=",
    "--project ",
    "--putenv=",
    "--rangeChecks=",
    "--refChecks=",
    "--run ",
    "--showAllMismatches=",
    "--skipCfg=",
    "--skipParentCfg=",
    "--skipProjCfg=",
    "--skipUserCfg=",
    "--stackTrace=",
    "--stdout=",
    "--styleCheck=",
    "--taintMode=",
    "--threadanalysis=",
    "--threads=",
    "--tlsEmulation=",
    "--trmacros=",
    "--undef=",
    "--useVersion=",
    "--verbosity=",
    "--version ",
    "--warningCannotOpenFile=",
    "--warningConfigDeprecated=",
    "--warningDeprecated=",
    "--warningEachIdentIsTuple=",
    "--warningOctalEscape=",
    "--warnings=",
    "--warningSmallLshouldNotBeUsed=",
    "--warningUser="
]
echo 1, " ", lcp(
    strs,
    charloop_startindex = 2,
    min_frqz_prefix_len = 2,
    min_prefix_len = 3,
    min_frqz_count = 3,
    char_break_points = ['='],
    prepend = "--",
    append = "..."
)

strs = @[
    "--app=",
    "--assertions=",
    "--boundChecks=",
    "--checks=",
    "--cincludes=",
    "--clib=",
    "--clibdir=",
    "--colors="
]
echo 2, " ", lcp(
    strs,
    charloop_startindex = 2,
    min_frqz_prefix_len = 2,
    min_prefix_len = 3,
    min_frqz_count = 3,
    char_break_points = ['='],
    prepend = "--",
    append = "..."
)

strs = @[
    "--warningCannotOpenFile",
    "--warningConfigDeprecated",
    "--warningDeprecated",
    "--warningEachIdentIsTuple",
    "--warningOctalEscape",
    "--warnings",
    "--warningSmallLshouldNotBeUsed",
    "--warningUser"
]
echo 3, " ", lcp(
    strs,
    charloop_startindex = 2,
    min_frqz_prefix_len = 2,
    min_prefix_len = 3,
    min_frqz_count = 3,
    char_break_points = ['='],
    prepend = "--",
    append = "..."
)

strs = @[
    "--skipCfg=",
    "--skipParentCfg=",
    "--skipProjCfg=",
    "--skipUserCfg="
]
echo 4, " ", lcp(
    strs,
    charloop_startindex = 2,
    min_frqz_prefix_len = 2,
    min_prefix_len = 3,
    min_frqz_count = 3,
    char_break_points = ['='],
    prepend = "--",
    append = "..."
)

strs = @[
    "--hintCC=",
    "--hintCodeBegin=",
    "--hintCodeEnd=",
    "--hintCondTrue=",
    "--hintConf=",
    "--hintConvFromXtoItselfNotNeeded=",
    "--hintConvToBaseNotNeeded=",
    "--hintDependency=",
    "--hintExec=",
    "--hintExprAlwaysX=",
    "--hintExtendedContext=",
    "--hintGCStats=",
    "--hintGlobalVar=",
    "--hintLineTooLong=",
    "--hintLink=",
    "--hintName=",
    "--hintPath=",
    "--hintPattern=",
    "--hintPerformance=",
    "--hintProcessing=",
    "--hintQuitCalled=",
    "--hints=",
    "--hintSource=",
    "--hintStackTrace=",
    "--hintSuccess=",
    "--hintSuccessX=",
    "--hintUser=",
    "--hintUserRaw="
]
echo 5, " ", lcp(
    strs,
    charloop_startindex = 2,
    min_frqz_prefix_len = 2,
    min_prefix_len = 3,
    min_frqz_count = 3,
    char_break_points = ['='],
    prepend = "--",
    append = "..."
)

strs = @[
    "--warnings=",
    "--warningCannotOpenFile=",
    "--warningXonfigDeprecated=",
    "--warningPofigApple=",
    "--warningCofigApple=",
    "--warningCofigApple=",
    "--warningCofigApple=",
    "--warningCofigApple=",
    "--warningCofigApple=",
    "--warningCofigApple=",
    "--warningCofgTest="
]
echo 6, " ", lcp(
    strs,
    charloop_startindex = 2,
    min_frqz_prefix_len = 2,
    min_prefix_len = 3,
    min_frqz_count = 3,
    char_break_points = ['='],
    prepend = "--",
    append = "..."
)

strs = @["--warnings=", "--warningCannotOpenFile="]
echo 7, " ", lcp(
    strs,
    charloop_startindex = 2,
    min_frqz_prefix_len = 2,
    min_prefix_len = 3,
    min_frqz_count = 3,
    char_break_points = ['='],
    prepend = "--",
    append = "..."
)

strs = @["--warnings="]
echo 8, " ", lcp(
    strs,
    charloop_startindex = 2,
    min_frqz_prefix_len = 2,
    min_prefix_len = 3,
    min_frqz_count = 3,
    char_break_points = ['='],
    prepend = "--",
    append = "..."
)

strs = @[
    "--hintCC=",
    "--hintCodeBegin=",
    "--hintCodeEnd=",
    "--hintCondTrue=",
    "--hintConf=",
    "--hintConvFromXtoItselfNotNeeded=",
    "--hintConvToBaseNotNeeded=",
    "--hintDependency=",
    "--hintExec=",
    "--hintExprAlwaysX=",
    "--hintExtendedContext=",
    "--hintGCStats=",
    "--hintGlobalVar=",
    "--hintLineTooLong=",
    "--hintLink=",
    "--hintName=",
    "--hintPath=",
    "--hintPattern=",
    "--hintPerformance=",
    "--hintProcessing=",
    "--hintQuitCalled=",
    "--hints=",
    "--hintSource=",
    "--hintStackTrace=",
    "--hintSuccess=",
    "--hintSuccessX=",
    "--hintUser=",
    "--hintUserRaw=",
    "--hintXDeclaredButNotUsed="
]
echo 9, " ", lcp(
    strs,
    charloop_startindex = 2,
    min_frqz_prefix_len = 2,
    min_prefix_len = 3,
    min_frqz_count = 3,
    char_break_points = ['='],
    prepend = "--",
    append = "..."
)

strs = @["--hintCC="]
echo 10, " ", lcp(
    strs,
    charloop_startindex = 2,
    min_frqz_prefix_len = 2,
    min_prefix_len = 3,
    min_frqz_count = 3,
    char_break_points = ['='],
    prepend = "--",
    append = "..."
)

strs = @["--hintUser=", "--hintUserRaw=", "--hintXDeclaredButNotUsed="]
echo 11, " ", lcp(
    strs,
    charloop_startindex = 2,
    min_frqz_prefix_len = 2,
    min_prefix_len = 3,
    min_frqz_count = 3,
    char_break_points = ['='],
    prepend = "--",
    append = "..."
)

strs = @[
    "--hintSuccessX=",
    "--hintUser=",
    "--hintUserRaw=",
    "--hintXDeclaredButNotUsed="
]
echo 12, " ", lcp(
    strs,
    charloop_startindex = 2,
    min_frqz_prefix_len = 2,
    min_prefix_len = 3,
    min_frqz_count = 3,
    char_break_points = ['='],
    prepend = "--",
    append = "..."
)

strs = @[
    "Call Mike and schedule meeting.",
    "Call Lisa",
    "Call Adam and ask for quote.",
    "Implement new class for iPhone project",
    "Implement new class for Rails controller",
    "Buy groceries"
]
echo 13, " ", lcp(strs)

strs = @["interspecies", "interstelar", "interstate"]
echo 14, lcp(strs) # "inters"
strs = @["throne", "throne"]
echo 15, lcp(strs) # "throne"
strs = @["throne", "dungeon"]
echo 16, lcp(strs) # ""
strs = @["cheese"]
echo 17, lcp(strs) # "cheese"
strs = @[]
echo 18, lcp(strs) # ""
strs = @["prefix", "suffix"]
echo 19, lcp(strs) # ""
