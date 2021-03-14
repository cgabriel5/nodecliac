from strutils import find
import os, memfiles, streams, tables

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

    type
        Range = array[2, int]
        DBEntry = Table[string, array[2, Range]]

    const LVL1 = 1
    const KEYWORD_LEN = 6

    const C_NL = '\n'
    const C_DOT = '.'
    const C_SPACE = ' '
    const C_ESCAPE = '\\'
    const C_NUMSIGN = '#'
    const C_UNDERSCORE = '_'
    const C_SRT_DOT = $C_SPACE
    const C_SPACE_DOT = { C_DOT, C_SPACE }
    const VALID_LINE_STARTS = { C_NUMSIGN, C_NL }

    const O_DEFAULT = 100 # (d)efault
    const O_FILEDIR = 102 # (f)iledir
    const O_CONTEXT = 99  # (c)ontext
    const O_HYPHEN  = 45  # hyphen

    var db_dict = initTable[char, DBEntry]()
    var db_levels = initTable[int, Table[string, int]]()
    var db_defaults = initTable[string, Range]()
    var db_filedirs = initTable[string, Range]()
    var db_contexts = initTable[string, Range]()

    let last = ""
    let lastchar = ' '
    let commandchain = ".disable"

    let hdir = getEnv("HOME")
    let fn = joinPath(hdir, ".nodecliac/registry/nodecliac/nodecliac.acdefBIG")

    # Count number of lines in file.
    # [https://forum.nim-lang.org/t/4680#29221]
    # [https://forum.nim-lang.org/t/3261]
    var line_count = 0
    var mf = memfiles.open(fn)
    for line in memSlices(mf): # Skip comment/empty lines.
        if cast[cstring](line.data)[0] notin VALID_LINE_STARTS: inc(line_count)
    mf.close()

    # [https://forum.nim-lang.org/t/4680]
    let mstrm = newMemMapFileStream(fn, fmRead)
    let text = mstrm.readAll()
    mstrm.close()

    var pos = 0
    var lastpos = 0
    var ranges = newSeqOfCap[Range](line_count)
    while true:
        pos = find(text, sub = C_NL, start = pos + 1)
        if pos == -1: break
        if lastpos != pos and text[lastpos] != C_NUMSIGN:
            ranges.add([lastpos, pos - 1])
        lastpos = pos + 1

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

    proc splitundel(chain: string, DEL: char = C_DOT): seq[string] =
        runnableExamples:
            let answer = @["", "first\\.escaped", "last"]
            assert splitundel(".first\\.escaped.last") == answer

        var lastpos = 0
        let EOS = chain.high
        for i, c in chain:
            if c == DEL and chain[i - 1] != C_ESCAPE:
                result.add(chain[lastpos .. i - 1])
                lastpos = i + 1
            elif i == EOS: result.add(chain[lastpos .. i])

    proc strfromrange(s: string, start, stop: int): string =
        # [https://forum.nim-lang.org/t/707#3931]
        # [https://forum.nim-lang.org/t/735#4170]
        result = newStringOfCap(stop - start)
        for i in countup(start, stop - 1): result.add(s[i])
        # The resulting indices may also be populated with builtin slice
        # notation. However, using a loop shows to be slightly faster.
        # [https://github.com/nim-lang/Nim/pull/2171/files]
        # result[result.low .. result.high] = s[start ..< stop]
        shallow(result)

    proc fn_makedb() =
        if commandchain == "": # First level commands only.
            if last == "":
                db_levels[LVL1] = initTable[string, int]()

                for rng in ranges:
                    let start = rng[0]
                    let stop = rng[1]

                    if text[start] == C_SPACE: continue

                    # Add 1 to start to skip the initial dot in command chain.
                    let command = strfromrange(text, start + 1, find(text, C_SPACE_DOT, start + 1, stop))
                    if command notin db_levels[LVL1]: db_levels[LVL1][command] = LVL1

            else: # First level flags.

                db_dict[C_UNDERSCORE] = DBEntry()

                for rng in ranges:
                    let start = rng[0]
                    let stop = rng[1]

                    if text[start] == C_SPACE:
                        db_dict[C_UNDERSCORE][$C_UNDERSCORE] = [[start, start], [start + 1, stop]]
                        break

        else: # Go through entire .acdef file contents.

            for rng in ranges:
                let start = rng[0]
                let stop = rng[1]

                # Line must start with commandchain
                if not cmpindices(text, commandchain, start, stop): continue

                # Locate the first space character in the line.
                let sindex = find(text, C_SPACE, start, stop)
                let chain = strfromrange(text, start, sindex)

                # # If retrieving next possible levels for the command chain,
                # # lastchar must be an empty space and the commandchain does
                # # not equal the chain of the line, skip the line.
                # if lastchar == C_SPACE and not chain.cmpstart(commandchain, C_SRT_DOT):
                #     continue

                # let commands = splitundel(chain)

                # Cleanup remainder (flag/command-string).
                let rindex = sindex + 1
                let fchar = chain[1]
                if ord(text[rindex]) == O_HYPHEN:
                    if fchar notin db_dict: db_dict[fchar] = DBEntry()
                    db_dict[fchar][chain] = [[start, sindex - 1], [rindex, stop]]

                else: # Store keywords.
                    # The index from the start of the keyword value string to end of line.
                    let value = [rindex + (KEYWORD_LEN + 2), stop]
                    case ord(text[rindex]): # Keyword first char keyword.
                    of O_DEFAULT:
                        if chain notin db_defaults: db_defaults[chain] = value
                    of O_FILEDIR:
                        if chain notin db_filedirs: db_filedirs[chain] = value
                    of O_CONTEXT:
                        if chain notin db_contexts: db_contexts[chain] = value
                    else: discard

    fn_makedb()

main()
