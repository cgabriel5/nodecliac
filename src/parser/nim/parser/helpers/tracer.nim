import std/strutils

import ../../utils/chalk
import ../helpers/types

# Basic tracing of parsers used for debugging.
#
# @return - Nothing is returned.
proc trace*(S: State, line_type: LineType) =
    if not S.args.trace: return # Only trace if flag is set.

    var msg = ""
    let line_num = S.line
    let last_line_num = S.last_line_num
    let parser = ($linetype)[2 .. ^1].toLower()

    msg = "Trace".chalk("magenta", "bold", "underline")
    if last_line_num == 0: echo msg # Print header.

    S.last_line_num = line_num

    # Add to last printed line: [https://stackoverflow.com/a/17309876]

    msg = ($line_num).chalk("bold") & " " & parser
    if line_num != last_line_num: echo msg
    else: echo " ~ " & parser.chalk("dim")
