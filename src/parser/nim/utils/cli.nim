import std/os

# Like 'commandLineParams' but returns all CLI input in a string.
#
# @return {string} - The CLI input.
proc input*(): string =
    var output = ""
    for i in 1..paramCount(): output &= paramStr(i)
    return output
