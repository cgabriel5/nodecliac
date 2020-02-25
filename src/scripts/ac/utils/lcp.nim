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
            strs: var openArray[string],
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
