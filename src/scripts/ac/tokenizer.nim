#!/usr/bin/env nim

proc main() =

    const C_NULLB = '\0'
    const C_ESCAPE = '\\'
    const C_COLON = ':'
    const C_EQUALSIGN = '='
    const C_HYPHEN = '-'
    const C_QUOTES = {'"', '\''}
    const C_SPACES = {' ', '\t'}
    const FLAGVAL_DELS = { C_COLON, C_EQUALSIGN }

    type
        ArgSlice = array[3, int]

    var input = """"""

    # Parses CLI input into its individual arguments and normalizes any
    #     flag/value ':' delimiters to '='.
    #
    # @return - Nothing is returned.
    proc fn_argslices(): seq[ArgSlice] =
        if input == "": return

        var c, p, q: char
        var start, eqsign: int = -1

        var i = 0; let l = input.len
        while i < l:
            swap(p, c)
            c = input[i]

            if q != C_NULLB:
                if c == q and p != C_ESCAPE:
                    if start != -1:
                        result.add([start, i, eqsign])
                        eqsign = -1
                        start = -1
                        q = C_NULLB

            else:
                if c in C_QUOTES and p != C_ESCAPE:
                    if start == -1:
                        start = i
                        q = c

                elif c in C_SPACES and p != C_ESCAPE:
                    if start != -1:
                        result.add([start, i - 1, eqsign])
                        eqsign = -1
                        start = -1

                else:
                    if start == -1: start = i
                    if c in FLAGVAL_DELS and eqsign == -1 and
                            input[start] == C_HYPHEN:
                        input[i] = C_EQUALSIGN # Normalize ':' to '='.
                        eqsign = i
            inc(i)

        # Finish last point post loop.
        if start > -1 and start != l: result.add([start, input.high, eqsign])

    let slices = fn_argslices()

    echo input
    for slice in slices:
        let start = slice[0]
        let last  = slice[1]
        let eqsign = slice[2]
        echo "[", input[start .. last], "]"

main()
