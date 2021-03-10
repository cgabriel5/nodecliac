import osproc, strutils, asyncdispatch

proc nlcli_bin*(s: string = "{}") {.async.} = stdout.write(execProcess("command -v nodecliac").strip())
