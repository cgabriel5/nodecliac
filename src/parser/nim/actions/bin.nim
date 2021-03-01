import osproc, strutils

proc bin() {.async.} = stdout.write(execProcess("command -v nodecliac").strip())
