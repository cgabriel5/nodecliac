import asyncdispatch, json, strutils

import ../utils/[chalk, config]

proc nlcli_status*(s: string = "{}") {.async.} =
    let jdata = parseJSON(s)
    let enable = jdata{"enable"}.getBool()
    let disable = jdata{"disable"}.getBool()

    initconfig()

    # If no flag is supplied only print the status.
    if not enable and not disable:
        let status = getsetting("status")
        let message = if status == "1": "on".chalk("green") else: "off".chalk("red")
        echo message
    else:
        if enable and disable:
            let varg1 = "--enable".chalk("bold")
            let varg2 = "--disable".chalk("bold")
            let tstring = "? and ? given when only one can be provided."
            quit(tstring % [varg1, varg2])

        if enable:
            setsetting("status", "1")
            echo "on".chalk("green")
        elif disable:
            # let contents = `Disabled: ${new Date()};${Date.now()}`;
            setsetting("status", "0")
            echo "off".chalk("red")
