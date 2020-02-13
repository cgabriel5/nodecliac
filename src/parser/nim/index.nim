from re import re, find, replace
from strutils import split, parseInt
from os import isAbsolute, absolutePath, existsDir, existsFile
from tables import `$`, pairs # [https://github.com/nim-lang/Nim/issues/11155]

import utils/[chalk, argvparse, exit]
from utils/fs import info, read
from parser/index import parser

let args = argvparse()
let igc = args.igc
let test = args.test
let print = args.print
let trace = args.trace
let action = args.action
var indent = args.indent
var source = args.source
let formatting = action == "format"

var fmtinfo: tuple[char: char, amount: int]
fmtinfo = (char: '\t', amount: 1)
# Parse/validate indentation.
if formatting and indent != "":
    let r = re"^(s|t):\d+$"
    if indent.find(r) == -1:
        echo "Invalid indentation string."
        exit()
    let components = indent.split(":", 2)
    fmtinfo.char = if components[0] == "s": ' ' else: '\t'
    fmtinfo.amount = components[1].parseInt()

# Source must be provided.
if source == "":
    echo "Please provide a " &  "--source".chalk("bold") & " path."
    exit()

# Breakdown path.
let fi = info(source)
let extension = fi.ext
let cmdname = fi.name.replace(re("\\." & extension & "$")) # [TODO] `replace`
let dirname = fi.dirname

# Make path absolute.
if not source.isAbsolute(): source = absolutePath(source)

if existsDir(source):
    echo "Directory provided but .acmap file path needed."
    exit()
if not existsFile(source):
    echo "Path " & source.chalk("bold") & " doesn't exist."
    exit()

let res = read(source)
let pres = parser(action, res, cmdname, source, fmtinfo, trace, igc, test)
# let { acdef, config, keywords, placeholders, formatted, time } = pres;
# let savename = `${cmdname}.acdef`;
# let saveconfigname = `.${cmdname}.config.acdef`;

# nim compile --run --warnings:off --hints:off --verbosity:1 --forceBuild:off --showAllMismatches:on index.nim && time ./index.sh make --source ~/Desktop/test.acmap --print --trace=false --test=false --strip-comments true --indent "t:22" --dub && rm -f index; nodecliac make --source ~/Desktop/test.acmap

# /opt/lampp/htdocs/projects/nodecliac/src/parser/nim
