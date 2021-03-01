import osproc

proc bin() {.async.} = stdout.write(execProcess("command -v nodecliac"))
