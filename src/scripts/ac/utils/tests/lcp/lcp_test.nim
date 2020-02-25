import json
import ../../lcp

let data = parseJson(readFile("./data.json"))

echo "\nCustoms:"
var i = 0
for custom in data["customs"].items:
    var list: seq[string] = @[]
    for word in custom.items: list.add(($word)[1 .. ^2])

    let res = lcp(
        list,
        charloop_startindex = 2,
        min_frqz_prefix_len = 2,
        min_prefix_len = 3,
        min_frqz_count = 3,
        char_break_points = ['='],
        prepend = "--",
        append = "..."
    ).prefixes
    echo i + 1, " ", res.len, " ", res
    inc(i)

echo "\nDefaults:"
i = 0
for default in data["defaults"].items:
    var list: seq[string] = @[]
    for word in default.items: list.add(($word)[1 .. ^2])

    let res = lcp(list).prefixes
    echo i + 1, " ", res.len, " ", res
    inc(i)
