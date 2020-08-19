from sequtils import toSeq
from osproc import execProcess
from os import getEnv, paramStr, paramCount, fileExists
from strutils import join, rfind, delete, parseInt, stripLineEnd
from sets import HashSet, initHashSet, incl, excl, contains, items
from nre import re, `[]`, get, find, split, isSome, captures, findIter

let argcount = os.paramCount()
if argcount == 0: quit()

let action = if argcount > 0: os.paramStr(1) else: ""
let useglobal = if argcount > 1: os.paramStr(2) else: ""
var cwd = os.getEnv("PWD")
let hdir = os.getEnv("HOME")
let input = os.getEnv("NODECLIAC_INPUT_ORIGINAL")
var pkg = ""

if useglobal == "":
    # If a workspace use its location.
    let test = find(input, re"^[ \t]*?yarn[ \t]+?workspace[ \t]+?([^ \t]+?)[ \t]+?.*")
    if test.isSome(): cwd = "/" & test.get.captures[0]

    while cwd != "":
        if fileExists(cwd & "/package.json"):
            pkg = cwd & "/package.json"
            break
        cwd.delete(cwd.rfind('/'), cwd.high)
else:
    let paths = [
        hdir & "/.config/yarn/global/package.json",
        hdir & "/.local/share/yarn/global/package.json",
        hdir & "/.yarn/global/package.json"
    ]

    for path in paths:
        if fileExists(path):
            pkg = path
            break

var args = initHashSet[string]()

if action == "run":
    if action != "":
        let pkgcontents = readFile(pkg)
        let p1 = re("\"scripts\"\\s*:\\s*{([\\s\\S]*?)}(,|$)")
        let p2 = re("\"([^\"]*)\"\\s*:")
        for m in findIter(pkgcontents, p1):
            for m in findIter(m.captures[0], p2):
                args.incl(m.captures[0])

elif action == "workspace":
    let workspaces_info = execProcess("LC_ALL=C yarn workspaces info -s 2> /dev/null")
    let args_count = os.getEnv("NODECLIAC_ARG_COUNT").parseInt()

    if (workspaces_info != "" and args_count <= 2) or (workspaces_info != "" and args_count <= 3 and os.getEnv("NODECLIAC_LAST_CHAR") != ""):
        # Get workspace names.
        let pattern = re("\"location\":\\s*\"([^\"]+)\",")
        for m in findIter(workspaces_info, pattern): args.incl(m.captures[0])

else: # Remaining actions: remove|outdated|unplug|upgrade
    if action != "":
        let pkgcontents = readFile(pkg)
        let p1 = re("\"(?:dependencies|devDependencies)\"\\s*:\\s*{([\\s\\S]*?)}(?:,|$)")
        let p2 = re("\"([^\"]*)\"\\s*:")
        for m in findIter(pkgcontents, p1):
            for k in findIter(m.captures[0], p2):
                args.incl(k.captures[0])

# let last = os.getEnv("NODECLIAC_LAST")
# let lchar = os.getEnv("NODECLIAC_LAST_CHAR")
# let nchar = os.getEnv("NODECLIAC_NEXT_CHAR")
var used = os.getEnv("NODECLIAC_USED_DEFAULT_POSITIONAL_ARGS")
used.stripLineEnd # Remove trailing newline.
let used_args = used.split(re"[\n ]")

for uarg in used_args:
    if args.contains(uarg):
        args.excl(uarg)
        args.incl("!" & uarg)

echo join(toSeq(args), "\n")
