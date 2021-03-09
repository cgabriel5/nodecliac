import os, memfiles, streams

import ./vla

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

    type Slice = tuple[start, `end`: int]

    let hdir = getEnv("HOME")
    let fn = joinPath(hdir, ".nodecliac/registry/nodecliac/nodecliac.acdef")
    # [https://forum.nim-lang.org/t/4680]
    let mstrm = newMemMapFileStream(fn, fmRead)
    let text = mstrm.readAll()
    mstrm.close()

    const C_NL = '\n'

    # Count number of lines in file.
    var counter = 0
    for line in memSlices(memfiles.open(fn)): inc(counter)

    var index = 0
    var lastpos = 0
    var ranges = newVLA(Slice, counter)
    # [https://forum.nim-lang.org/t/4680#29221]
    # [https://forum.nim-lang.org/t/3261]
    for pos in countup(0, text.high):
        if text[pos] == C_NL:
            ranges[index] = (lastpos, pos)
            inc(index)
            lastpos = pos

    # for i in countup(0, ranges.len - 1):
    # for i in countup(0, 20):
    #     echo ranges[i]

main()
