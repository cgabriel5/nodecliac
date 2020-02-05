from terminal import Style, ForegroundColor, BackgroundColor
from unicode import toLower
from tables import `$`, `[]`, `[]=`, hasKey, initTable
from re import re, replace

var lookup = initTable[string, int]()
# Build lookup table containing style:code.
# [https://forum.nim-lang.org/t/5052#31708]
for s in Style.low..Style.high:
    var style = $s
    style = style[5..style.len-1].toLower()
    if style == "bright": style = "bold"
    lookup[style] = ord(s)
for c in ForegroundColor.low..ForegroundColor.high:
    var color = $c
    color = color[2..color.len-1].toLower()
    lookup[color] = ord(c)
for c in BackgroundColor.low..BackgroundColor.high:
    lookup[($c).toLower()] = ord(c)

# Simple colored logging inspired by: [https://www.npmjs.com/package/chalk]
#
# @return {object} - Object containing needed CLI arguments.
proc chalk*(s: string, styles: varargs[string]): string =
    var starting = "\e[" # [https://forum.nim-lang.org/t/3556#25477]
    let closing = "\e[0m"
    let l = styles.len
    var i = 0
    var str = s
    let r = re"\x1b\[[0-9;]*[mG]" # [https://superuser.com/a/561105]
    for style in styles:
        if style == "strip": str = str.replace(r)
        elif lookup.hasKey(style):
            starting &= $lookup[style]
            if i != l - 1: starting &= ";"
        inc(i)
    return starting & "m" & str & closing
