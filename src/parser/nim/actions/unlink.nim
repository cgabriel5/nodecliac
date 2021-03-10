import asyncdispatch, ./remove

# Action is an alias for 'remove' action.
proc nlcli_unlink*(s: string = "{}") {.async.} = asyncCheck nlcli_remove(s)
