import strformat
from strutils import startsWith, join
from sets import HashSet, initHashSet, incl
from os import paramCount, commandLineParams
from parseopt import next, cmdEnd, cmdArgument, cmdLongOption,
    initOptParser, cmdShortOption
from json import newJObject, newJString, newJArray, newJBool,
    JString, hasKey, getStr, delete, add, `$`, `%*`, `[]`, `[]=`

type
    Argument* = ref object
        key*, val*, hyphens*, `type`*: string
        singleton*: bool

# Goes through CLI arguments and returns an array of Arguments.
#
# @return {array} - Array of arguments is returned.
proc argvparse*(): tuple[ args: seq[Argument], json: string,
                            usedf: HashSet[string], positional: seq[string] ] =
    let args = commandLineParams()
    var p = initOptParser(allowWhitespaceAfterColon = false)
    var i = 0
    let l = args.len;
    var A: Argument

    var arguments: seq[Argument] = @[]
    var positional: seq[string] = @[]
    var cliinput: seq[string] = @[]
    var usedflags = initHashSet[string]()

    # Create setup info file to reference on uninstall.
    let data = newJObject()

    # Adds key/value pair to JSON string.
    #
    # @param  {string} key - The key entry.
    # @param  {string} val - The key's value.
    # @return {undefined} - Nothin is returned.
    proc build_json(key, val: string, isbool: bool = false) =
        # [TODO] Add logic to take into account numbers and booleans.
        # [https://github.com/substack/minimist/blob/master/index.js]
        # proc isNumber(s: string): bool =
        #     if (typeof x === 'number') return true;
        #     if (/^0x[0-9a-f]+$/i.test(x)) return true;
        #     return /^[-+]?(?:\d+(?:\.\d*)?|\.\d+)(e[-+]?\d+)?$/.test(x);

        if not isbool:
            if not data.hasKey(key):
                data.add(key, newJString(val))
            else:
                var oval = data[key]
                if oval.kind == JString:
                    data.delete(key)
                    var values = newJArray()
                    values.add(newJString(oval.getStr()))
                    values.add(newJString(val))
                    data.add(key, values)
                else:
                    oval.add(newJString(val))
        else:
            if not data.hasKey(key):
                data.add(key, newJBool(true))
            else:
                var oval = data[key]
                if oval.kind == JString:
                    data.delete(key)
                    var values = newJArray()
                    values.add(newJBool(true))
                    values.add(newJBool(true))
                    data.add(key, values)
                else:
                    oval.add(newJBool(true))

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
                    build_json(p.key, nitem)
                    usedflags.incl(p.key)
                    A = Argument(
                        key: p.key,
                        val: nitem,
                        `type`: "pair",
                        hyphens: hyphens,
                        singleton: issingleton
                    )
                    cliinput.add(fmt"""{hyphens}{p.key}={nitem}""")
                    inc(i)
                    p.next()
                else: # Valueless flags (i.e. --flag or -f).
                    build_json(p.key, "true", isbool=true)
                    usedflags.incl(p.key)
                    A = Argument(
                        key: p.key,
                        hyphens: hyphens,
                        singleton: issingleton
                    )
                    cliinput.add(fmt"""{hyphens}{p.key}""")
            else: # Handle --key=value or -k=v.
                build_json(p.key, p.val)
                usedflags.incl(p.key)
                A = Argument(
                    key: p.key,
                    val: p.val,
                    `type`: "pair",
                    hyphens: hyphens,
                    singleton: issingleton
                )
                cliinput.add(fmt"""{hyphens}{p.key}={p.val}""")
        of cmdArgument:
            positional.add(p.key)
            A = Argument(key: p.key, `type`: "positional")
            cliinput.add(fmt"""{p.key}""")

        arguments.add(A)
        inc(i)

    data["_"] = %* positional
    data["__args"] = %* cliinput
    data["__input"] = %* cliinput.join(" ")

    result.args = arguments
    result.json = $data
    result.usedf = usedflags
    result.positional = positional
