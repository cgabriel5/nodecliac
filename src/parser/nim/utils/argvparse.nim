from re import re, replace
from strutils import startsWith
from os import paramCount, commandLineParams
from parseopt import next, cmdEnd, cmdArgument,
    cmdLongOption, initOptParser, cmdShortOption

from fs import expand_tilde

if os.paramCount() == 0: quit() # Exit if no args.

type Arguments = ref object
    action*, source*, indent*: string
    print*, trace*, test*, igc*: bool

# Add value to key in Args object.
#
# @return - Nothing is returned.
proc set(A: Arguments, s: string, nitem: string, boolval: string) =
    if s == "source": A.source = nitem
    elif s == "indent": A.indent = nitem
    else:
        let val = if boolval == "1": true else: false
        case (s):
        of "print": A.print = val
        of "trace": A.trace = val
        of "test": A.test = val
        of "strip-comments": A.igc = val
        else: discard

# Get needed arguments from CLI input.
#
# @return {object} - Object containing needed CLI arguments.
proc argvparse*(): Arguments =
    new(result)

    let args = commandLineParams()
    var p = initOptParser(
        args[1 .. args.len - 1],  # Exclude action.
        allowWhitespaceAfterColon = false
    )
    var i = 1
    let l = args.len;
    let r = re"^-*"
    while true:
        p.next()
        case p.kind
        of cmdShortOption, cmdLongOption, cmdEnd:
            if p.kind == cmdEnd: break
            let flag = args[i].replace(r)
            if p.val == "" and flag != p.key & "=": # Handle --key value (no '=')
                if i + 1 < l and not args[i + 1].startsWith('-'): # Lookahead
                    let nitem = args[i + 1]
                    set(result, p.key, nitem, if nitem == "false": "0" else: "1")
                    inc(i)
                    p.next()
                else: set(result, p.key, "", "1")
            else: # Handle --key=value
                set(result, p.key, p.val, if p.val == "false": "0" else: "1")
        of cmdArgument: discard
        inc(i)

    result.action = args[0]
    result.source = expand_tilde(result.source)
