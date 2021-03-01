from strutils import startsWith
from os import paramCount, commandLineParams
from parseopt import next, cmdEnd, cmdArgument,
    cmdLongOption, initOptParser, cmdShortOption

# if os.paramCount() == 0: quit()

type
    Argument* = ref object
        key*, val*, hyphens*, `type`*: string
        singleton*: bool

# Goes through CLI arguments and returns an array of Arguments.
#
# @return {array} - Array of arguments is returned.
proc argvparse*(): seq[Argument] =
    let args = commandLineParams()
    var p = initOptParser(allowWhitespaceAfterColon = false)
    var i = 0
    let l = args.len;
    var A: Argument
    const hyphen = {'-'}

    while true:
        p.next()

        case p.kind
        of cmdShortOption, cmdLongOption, cmdEnd:
            if p.kind == cmdEnd: break
            let arg = args[i]
            let hyphens = (
                if arg[0] == '-':
                    if arg.len > 1 and arg[1] == '-': "--"
                    else: "-"
                else: ""
            )
            let flag = arg[hyphens.len .. ^1]
            let issingleton = hyphens.len == 1

            if p.val == "" and flag != p.key & "=": # Handle --key value (no '=').
                if i + 1 < l and not args[i + 1].startsWith('-'): # Lookahead.
                    let nitem = args[i + 1]
                    A = Argument(
                        key: p.key,
                        val: nitem,
                        `type`: "pair",
                        hyphens: hyphens,
                        singleton: issingleton
                    )
                    inc(i)
                    p.next()
                else: # Valueless flags (i.e. --flag or -f).
                    A = Argument(
                        key: p.key,
                        hyphens: hyphens,
                        singleton: issingleton
                    )
            else: # Handle --key=value or -k=v.
                A = Argument(
                    key: p.key,
                    val: p.val,
                    `type`: "pair",
                    hyphens: hyphens,
                    singleton: issingleton
                )
        of cmdArgument:
            A = Argument(key: p.key, `type`: "positional")

        result.add(A)
        inc(i)

# import "../src/parser/nim/utils/chalk"

# # $ nim c argvparse.nim && ./argvparse --flag value --flag2=value2 --foo bar -f=b -x y -a="str" -b "cstr" --left --debug=3 -l -r=2 ARG1
# let args = argvparse()
# for arg in args: echo arg[]
# echo "SOME".chalk("red")
# echo ">>> [" & "||||".chalk(["magenta", "bold", "underline"])
# echo "))".chalk("underline", "bold") & ":"
# echo "Please provide a " &  "--source".chalk("bold") & " path."
# echo "Please provide a " &  "--source".chalk(true, "bold") & " path."
