import std/asyncdispatch

import ./enable

# Call 'enable' action as virtually same logic.
proc nlcli_disable*(s: string = "{}") {.async.} = asyncCheck nlcli_enable(s)
