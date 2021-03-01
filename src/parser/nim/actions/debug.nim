import strutils

proc debug() {.async.} =
    initconfig()

    if enablencliac and disablencliac:
        let varg1 = "--enable".chalk("bold")
        let varg2 = "--disable".chalk("bold")
        let tstring = "$1 and $2 given when only one can be provided.";
        quit(tstring % [varg1, varg2])

    # 0=off , 1=debug , 2=debug + ac.pl , 3=debug + ac.nim
    if debug_enable:
        let dl = (
            if debug_script == "nim": 3
            elif debug_script == "perl": 2
            else: 1
        )
        setsetting("debug", $dl)
        echo "on".chalk("green")
    elif debug_disable:
        setsetting("debug", "0")
        echo "off".chalk("red")
    else:
        stdout.write(getsetting("debug"))
