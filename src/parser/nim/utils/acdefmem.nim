import os, memfiles, streams
from strutils import find
import tables #, strtabs

# import ./vla

# String, StringBuiler, newStringOfCap, shallowCopy/shallow
# [https://github.com/nim-lang/Nim/issues/8317]
# [https://forum.nim-lang.org/t/4182]
# [https://gist.github.com/Varriount/c3ba438533497bc636da]
# [https://forum.nim-lang.org/t/1793]
# [https://nim-lang.org/docs/system.html#newStringOfCap%2CNatural]

# Unicode length:
# [https://hsivonen.fi/string-length/]
# [https://github.com/nim-lang/Nim/issues/10911]
# [https://forum.nim-lang.org/t/4777]

# readChars():
# [https://stackoverflow.com/questions/48186397/nim-readchar-deprecated-what-to-use-instead]
# [https://peterme.net/handling-files-in-nim.html]
# [https://forum.nim-lang.org/t/5100#32042]
# [https://forum.nim-lang.org/t/4706]
# [https://www.reddit.com/r/nim/comments/8gylzf/handling_files_in_nim/]

# Lexbase/strscans: [https://forum.nim-lang.org/t/5103#32069]
# withValue (Tables): [https://forum.nim-lang.org/t/3062#19258]
# [https://nim-lang.org/docs/tables.html#withValue.t%2CTable%5BA%2CB%5D%2CA%2Cuntyped%2Cuntyped]
# String slices: [https://forum.nim-lang.org/t/3062#19258]
# String slow concatenation: [https://github.com/nim-lang/Nim/issues/8317]
# Use different compiler (i.e. clang): [https://forum.nim-lang.org/t/2387]
# stdout.write: [https://forum.nim-lang.org/t/6253#38601]

proc main =

    const C_NL = '\n'
    const C_DOT = '.'
    const C_SLASH = '\\'
    const C_SPACE = ' ' # {' ', '\t', '\v', '\c', '\n', '\f'}
    const C_NUMSIGN = '#'

    # var db_dict = initTable[char, Table[string, Table[string, seq[string]]]]()
    # var db_levels = initTable[int, Table[string, int]]()
    # var db_defaults = newStringTable()
    # var db_filedirs = newStringTable()
    # var db_contexts = newStringTable()

    # type Range = tuple[start, stop: int]
    type Range = array[2, int]

    let hdir = getEnv("HOME")
    # let fn = joinPath(hdir, ".nodecliac/registry/nodecliac/nodecliac.acdefBIG_ALL")
    let fn = joinPath(hdir, ".nodecliac/registry/nodecliac/nodecliac.acdefBIG")
    # let fn = joinPath(hdir, ".nodecliac/registry/nodecliac/nodecliac.acdef")


    # # Count number of lines in file.
    # var ranges: seq[Range] = @[]
    # var counter = 0
    # var pos = 0
    # var ff = memfiles.open(fn)
    # var length = 0
    # # var text = ""
    # for line in memSlices(ff):
    #     length = line.size
    #     ranges.add([pos, pos + length - 1])
    #     pos += length + 1
    #     inc(counter)
    # ff.close()

    # Count number of lines in file.
    var counter = 0
    const VALID_LINE_STARTS = { C_NUMSIGN, C_NL }
    var ff = memfiles.open(fn)
    for line in memSlices(ff): # Skip comment/empty lines.
        if cast[cstring](line.data)[0] notin VALID_LINE_STARTS: inc(counter)
    ff.close()

    # [https://forum.nim-lang.org/t/4680]
    let mstrm = newMemMapFileStream(fn, fmRead)
    let text = mstrm.readAll()
    mstrm.close()

    # var index = 0
    var lastpos = 0
    # var ranges = newVLA(Range, counter)
    var ranges = newSeqOfCap[Range](counter)
    # var ranges: seq[Range] = @[]
    # [https://forum.nim-lang.org/t/4680#29221]
    # [https://forum.nim-lang.org/t/3261]
    # for pos in countup(0, text.high):
    # for pos, c in text:
    #     if ord(c) == 10:
    #         # ranges[index] = (lastpos, pos - 1)
    #         # ranges.add((lastpos, pos - 1))
    #         ranges.add([lastpos, pos - 1])
    #         # inc(index)
    #         lastpos = pos + 1

    var pocx = 0
    while true:
        pocx = find(text, sub = C_NL, start = pocx + 1)
        if pocx == -1: break
        if lastpos != pocx and text[lastpos] != C_NUMSIGN:
            ranges.add([lastpos, pocx - 1])
        lastpos = pocx + 1

    let commandchain = ".disable"
    # shallow(commandchain)

    # Checks whether string starts with given substring and optional suffix.
    proc cmpstart(s, sub, suffix: string = ""): bool =
        runnableExamples:
          var s, sub: string = ""

          s = ".disable.second"
          sub = ".disable"
          doAssert cmpstart(s, sub, suffix = ".") == true

          s = ".disable.second"
          sub = ".disable.last"
          doAssert cmpstart(s, sub, suffix = ".") == false

          s = ".disable.second"
          sub = ".disable"
          doAssert cmpstart(s, sub, suffix = "+") == false

        let ls = suffix.len
        if (sub.len + ls) > (s.len + ls): return

        var i = 0
        for c in sub:
            if sub[i] != s[i]: return
            inc(i)

        # Compare suffix if provided.
        if ls > 0:
            for c in suffix:
              if c != s[i]: return
              inc(i)

        return true

    # Checks whether provided substring is found at the start/stop indices
    #     at the source string.
    proc cmpindices(s, sub: string, start, stop: int): bool =
        if sub.len > (stop - start): return

        var index = start
        for c in sub:
            if c != s[index]: return
            inc(index)
        return true

    proc find_space_index(start, stop: int): int =
        for i in countup(start, stop):
            if text[i] == C_SPACE: return i
        return -1

    proc splitundel(chain: string, DEL: char = C_DOT): seq[string] =
        var lastpos = 0
        let EOS = chain.high
        for i, c in chain:
            if c == DEL and chain[i - 1] != C_SLASH:
                result.add(chain[lastpos .. i - 1])
                lastpos = i + 1
            elif i == EOS: result.add(chain[lastpos .. i])

    # proc splitundel(chain: string, DEL: char = C_DOT): seq[string] =
    #     # [https://forum.nim-lang.org/t/707#3931]
    #     # [https://forum.nim-lang.org/t/735#4170]
    #     proc getsubstr(start, stop: int): string =
    #         result = newStringOfCap(stop - start)
    #         for i in countup(start, stop): result.add(chain[i])
    #         shallow(result)

    #     var lastpos = 0
    #     let EOS = chain.high
    #     for i, c in chain:
    #         if c == DEL and chain[i - 1] != C_SLASH:
    #             result.add(getsubstr(lastpos, i - 1))
    #             lastpos = i + 1
    #         elif i == EOS: result.add(getsubstr(lastpos, i))

    #     runnableExamples:
    #         let answer = @["", "first\\.escaped", "last"]
    #         assert splitundel(".first\\.escaped.last") == answer

    # proc get_chain(start, stop: int): tuple[s: string, l: int] =
    #     # Locate the first space character in the line.
    #     let space_index = find_space_index(start, stop)
    #     # let space_index = text.find(C_SPACE, start, stop)
    #     var s = newStringOfCap(space_index - start)
    #     for i in countup(start, space_index - 1): s.add(text[i])
    #     shallow(s)
    #     result = (s, s.len)

    # type DBEntry = Table[string, Table[string, seq[string]]]
    type DBEntry = Table[string, array[2, Range]]

    # var db_dict = initTable[char, Table[string, Table[string, seq[string]]]]()
    var db_dict = initTable[char, DBEntry]()
    var db_levels = initTable[int, Table[string, int]]()
    # var db_defaults = newStringTable()
    var db_defaults = initTable[string, Range]()
    # var db_filedirs = newStringTable()
    var db_filedirs = initTable[string, Range]()
    # var db_contexts = newStringTable()
    var db_contexts = initTable[string, Range]()

    # initTable[string, Table[string, seq[string]]]()

    # proc strfrom(start, stop: int): tuple[s: string, l: int] =
    proc strfrom(start, stop: int): string =
        var s = newStringOfCap(stop - start)
        for i in countup(start, stop - 1): s.add(text[i])
        shallow(s)
        # result = (s, s.len)
        return s

    # var start, stop, ostart: int = 0
    var start, stop, rindex: int = 0
    var rchar: char
    # const T_FLAG_LABEL = "flags"
    # const T_CMDS_LABEL = "commands"
    const T_KW_DEFAULT = 100 # default
    const T_KW_FILEDIR = 102 # filedir
    const T_KW_CONTEXT = 99 # context
    const KEYWORD_LEN = 6
    const C_SRT_DOT = "."
    let lastchar = ' '
    # for i in countup(0, ranges.high):
    for rng in ranges:
        # (start, stop) = ranges[i]
        start = rng[0]
        # ostart = start
        stop = rng[1]

        # Line must start with commandchain
        if not cmpindices(text, commandchain, start, stop): continue

        # Locate the first space character in the line.
        let sindex = find_space_index(start, stop)
        let chain = strfrom(start, sindex)

        # let (chain, clen) = get_chain(start, stop)

        # # If retrieving next possible levels for the command chain,
        # # lastchar must be an empty space and the commandchain does
        # # not equal the chain of the line, skip the line.
        # if lastchar == C_SPACE and not chain.cmpstart(commandchain, C_SRT_DOT):
        #     continue

        # let commands = splitundel(chain)

        # Point index to the character after the chain and initial space.
        # start += clen + 1

        # Cleanup remainder (flag/command-string).
        rindex = sindex + 1
        rchar = text[rindex]
        if ord(rchar) == 45:
            if rchar notin db_dict: db_dict[rchar] = DBEntry()
            # db_dict[rchar][chain] = {T_CMDS_LABEL: @[""], T_FLAG_LABEL: @[""]}.toTable
            db_dict[rchar][chain] = [[start, sindex - 1], [rindex, stop]]

        else: # Store keywords.
            # The index from the start of the keyword value string to end of line.
            let value = [rindex + (KEYWORD_LEN + 2), stop]
            case ord(text[rindex]): # Keyword first char keyword.
                of T_KW_DEFAULT:
                    if chain notin db_defaults: db_defaults[chain] = value
                of T_KW_FILEDIR:
                    if chain notin db_filedirs: db_filedirs[chain] = value
                of T_KW_CONTEXT:
                    if chain notin db_contexts: db_contexts[chain] = value
                else: discard

    # echo db_dict
    # echo db_levels
    # echo db_defaults
    # echo db_filedirs
    # echo db_contexts

main()
