import std/re

# Like findBounds() but returns all found bounds in a sequence.
#
# @param  {string} s - The string to search.
# @param  {regex} pattern - The RegExp to search against.
# @return {sequence} - Sequence containing all bounds.
proc findAllBounds*(s: string, pattern: Regex): seq[tuple[first, last: int]] =
    var bounds: seq[tuple[first, last: int]] = @[]
    var offset = 0

    while true:
        var res = findBounds(s, pattern, start=offset)
        if res.first == -1: break
        bounds.add(res)
        offset = res.last

    result = bounds
