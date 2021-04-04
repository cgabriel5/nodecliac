import std/distros

proc platform*(): string =
    if detectOs(Linux): return "linux"
    if detectOs(MacOSX): return "macosx"
    if detectOs(Windows): return "windows"
    if detectOs(BSD): return "bsd"
    return "unknown"
