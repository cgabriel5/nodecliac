import ../utils/config

proc status() {.async.} =

    initconfig()

    # If no flag is supplied only print the status.
    if not enablencliac and not disablencliac:
        let status = getsetting("status")
        let message = if status == "1": "on".chalk("green") else: "off".chalk("red")
        echo message
    else:
        if enablencliac and disablencliac:
            let varg1 = "--enable".chalk("bold")
            let varg2 = "--disable".chalk("bold")
            let tstring = "? and ? given when only one can be provided."
            quit(tstring % [varg1, varg2])

        if enablencliac:
            setsetting("status", "1")
            echo "on".chalk("green")
        elif disablencliac:
            # let contents = `Disabled: ${new Date()};${Date.now()}`;
            setsetting("status", "0")
            echo "off".chalk("red")
