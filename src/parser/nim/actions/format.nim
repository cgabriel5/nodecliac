import asyncdispatch, ./make

# 'make' and 'format' functions share logic so call make action.
proc nlcli_format*(s: string = "{}") {.async.} = asyncCheck nlcli_make(s)
