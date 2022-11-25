import std/[re, unicode, tables, terminal]

# [https://nim-lang.org/docs/manual.html#modules-export-statement]
# [https://github.com/nim-lang/Nim/issues/11155]
export tables.`$`

var lookup = initTable[string, int]()
# Build lookup table: { style:code }.
# [https://forum.nim-lang.org/t/5052#31708]
for s in Style.low..Style.high:
    var style = $s
    style = style[5 .. style.len-1].toLower()
    if style == "bright": style = "bold"
    if style == "underscore": style = "underline"
    lookup[style] = ord(s)
for c in ForegroundColor.low..ForegroundColor.high:
    var color = $c
    color = color[2 .. color.len-1].toLower()
    lookup[color] = ord(c)
for c in BackgroundColor.low..BackgroundColor.high:
    lookup[($c).toLower()] = ord(c)

let r = re"\x1b\[[0-9;]*[mG]" # [https://superuser.com/a/561105]

# Simple colored logging inspired by: [https://www.npmjs.com/package/chalk]
#
# @param  {array} styles - List of styles to apply.
# @param  {bool} debug - Returns the actual ANSI escape string.
# @return {string} - The highlighted string or ANSI escaped string.
proc chalk*(s: string, styles: varargs[string]): string =
    var starting = "\e[" # [https://forum.nim-lang.org/t/3556#25477]
    let closing = "\e[0m"
    let l = styles.len
    var i = 0
    var str = s
    for style in styles:
        if style == "strip": str = str.replace(r)
        elif lookup.hasKey(style):
            starting &= $lookup[style]
            if i != l - 1: starting &= ";"
        inc(i)
    return starting & "m" & str & closing

# Overload chalk function to have a debuggable version which prints outs
#     ASCI color escape representation.
#
# @param  {array} styles - List of styles to apply.
# @param  {bool} debug - Returns the actual ANSI escape string.
# @return {string} - The highlighted string or ANSI escaped string.
proc chalk*(s: string, debug: bool, styles: varargs[string]): string =
    # [https://forum.nim-lang.org/t/3556#25477]
    var starting = "\\e[" # [https://forum.nim-lang.org/t/3556#25477]
    let closing = "\\e[0m"
    let l = styles.len
    var i = 0
    var str = s
    for style in styles:
        if style == "strip": str = str.replace(r)
        elif lookup.hasKey(style):
            starting &= $lookup[style]
            if i != l - 1: starting &= ";"
        inc(i)
    return starting & "m" & str & closing

const pattern = # [https://github.com/chalk/ansi-regex/blob/main/index.js]
    "[\\\u001B\\\u009B][[\\]()#;?]*(?:(?:(?:[a-zA-Z\\d]*(?:;[-a-zA-Z\\d\\/#&.:=?%@~_]*)*)?\\\u0007)" & "|" &
    "(?:(?:\\d{1,4}(?:;\\d{0,4})*)?[\\dA-PR-TZcf-ntqry=><~]))"

proc stripansi*(s: string): string =
    runnableExamples:
        doAssert stripansi("\u001B[4mName\u001B[0m") == "Name"
        doAssert stripansi("\u001b[31mHello\u001B[0m \u001b[31mWorld\u001B[0m!") == "Hello World!"

    s.replace(re(pattern, {reMultiLine}))
