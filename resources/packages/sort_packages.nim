from re import `=~`, re
from algorithm import sort
from os import `/`, splitPath
from options import Option, isNone, option, get
from json import `[]`, `%`, parseJSON, items, to, pretty, JsonNode
from strutils import toLower, join, splitLines, strip, repeat

type
  Package = object
    name, repo, scheme, `method`, description, license: Option[string]
    tags: Option[seq[string]]

const pkgname = "packages.json"
let filepath = currentSourcePath().splitPath.head / pkgname
let contents = readFile(filepath)
var packages: seq[tuple[name: string, pkg: Package]] = @[]

var jdata: JsonNode
try:
    jdata = parseJSON(contents)
except:
    let msg = getCurrentExceptionMsg()
    echo "\e[31mError:\e[0m [JSON Parsing failed]: " & msg

const empty_str = ""
const empty_list: seq[string] = @[]
for item in items(jdata):
    var package = to(item, Package)
    if package.name.isNone: package.name = option(empty_str)
    if package.repo.isNone: package.repo = option(empty_str)
    if package.scheme.isNone: package.scheme = option(empty_str)
    if package.`method`.isNone: package.`method` = option(empty_str)
    if package.description.isNone: package.description = option(empty_str)
    if package.license.isNone: package.license = option(empty_str)
    if package.tags.isNone: package.tags = option(empty_list)

    var p: tuple[name: string, pkg: Package]
    p = (name: package.name.get(), pkg: package)
    packages.add(p)

# [https://stackoverflow.com/a/6712058]
proc alphasort(a, b: tuple[name: string, pkg: Package]): int =
    let aname = a.name.toLower()
    let bname = b.name.toLower()
    if aname < bname: result = -1 # Sort string ascending.
    elif aname > bname: result = 1
    else: result = 0 # Default return value (no sorting).
packages.sort(alphasort)

const spaces = 4
var package_nodes: seq[string]
for item in packages: package_nodes.add(pretty(%item.pkg, spaces))
let jstr = package_nodes.join(",\n")

var padded_lines: seq[string] = @[]
for line in splitLines(jstr):
    var cline = line.strip(leading = true, trailing = false)
    if line =~ re"^(\s*)":
        let l = matches[0].len
        var padding = 1
        if l > 0: padding += l div spaces
        cline = "\t".repeat(padding) & cline
    padded_lines.add(cline)

writeFile(filepath, "[\n" & padded_lines.join("\n") & "\n]")
