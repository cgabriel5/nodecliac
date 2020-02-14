from re import re, replace
from strutils import startsWith
from os import paramCount, commandLineParams
from parseopt import next, cmdEnd, cmdArgument,
    cmdLongOption, initOptParser, cmdShortOption

from fs import expand_tilde

if os.paramCount() == 0: quit() # Exit if no args.
let args = commandLineParams()

type Arguments = ref object of RootObj
    action*: string
    source*: string
    indent*: string
    print*: bool
    trace*: bool
    test*: bool
    igc*: bool
let Args = Arguments(action: args[0])

# Add value to key in Args object.
#
# @return - Nothing is returned.
proc set(s: string, nitem: string, boolval: string) =
    if s == "source": Args.source = nitem
    elif s == "indent": Args.indent = nitem
    else:
        let val = if boolval == "1": true else: false
        case (s):
        of "print": Args.print = val
        of "trace": Args.trace = val
        of "test": Args.test = val
        of "strip-comments": Args.igc = val
        else: discard

# Get needed arguments from CLI input.
#
# @return {object} - Object containing needed CLI arguments.
proc argvparse*(): Arguments =
    var p = initOptParser(
        args[1..args.len - 1],
        allowWhitespaceAfterColon = false
    ) # Exclude action.
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
                    set(p.key, nitem, if nitem == "false": "0" else: "1")
                    inc(i)
                    p.next()
                else: set(p.key, "", "1")
            else: # Handle --key=value
                set(p.key, p.val, if p.val == "false": "0" else: "1")
        of cmdArgument: discard
        inc(i)

    Args.source = expand_tilde(Args.source)
    return Args
