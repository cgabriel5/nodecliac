import strutils, asyncdispatch, json

import ../utils/[chalk, config]

proc nlcli_debug*(s: string = "{}") {.async.} =
    let jdata = parseJSON(s)
    let enable = jdata{"enable"}.getStr()
    let disable = jdata{"disable"}.getStr()
    var script = jdata{"script"}.getStr()

    initconfig()

    if enable.len != 0 and disable.len != 0:
        let varg1 = "--enable".chalk("bold")
        let varg2 = "--disable".chalk("bold")
        let tstring = "$1 and $2 given when only one can be provided.";
        quit(tstring % [varg1, varg2])

    # 0=off , 1=debug , 2=debug + ac.pl , 3=debug + ac.nim
    if enable.len != 0:
        let dl = (
            if script == "nim": 3
            elif script == "perl": 2
            else: 1
        )
        setsetting("debug", $dl)
        echo "on".chalk("green")
    elif disable.len != 0:
        setsetting("debug", "0")
        echo "off".chalk("red")
    else:
        stdout.write(getsetting("debug"))
