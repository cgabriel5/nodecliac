import os, algorithm, browsers, webgui, parsecfg, strformat, osproc, asyncdispatch, re
from times import format, getTime, toUnix
import strutils except escape
from xmltree import escape
import uri
import json
import httpclient
import tables
import streams
# from typetraits import name

# [https://forum.nim-lang.org/t/6474#39947]
type
    Response = ref object
        code: int
        resp: string
        names: ptr seq[tuple[name, version: string, disabled: bool]]
        # outdated: ptr seq[tuple[name, version: string]]
        outdated: ptr seq[tuple[name, local_version, remote_version: string, config: OrderedTableRef[string, OrderedTableRef[string, string]]]]
    ChannelMsg = object
        action, cmd: string
        future: ptr Future[Response]
        list: ptr seq[string]
        # jdata: ptr jsonNode
        all: bool
#
# [https://forum.nim-lang.org/t/3640]
# var fut {.threadvar.}: Future[Response]
#
# [https://nim-lang.org/docs/channels.html]
# [https://nim-lang.org/docs/threads.html]
# [https://nim-lang.org/docs/locks.html]
# [https://github.com/nim-lang/Nim/issues/13936]
# [https://github.com/nim-lang/RFCs/issues/183]
# [https://forum.nim-lang.org/t/1572#9868]

when defined(linux):
    const width = 900 + 1100
    const height = 900 + 750
    const minWidth = 950
    const minHeight = 600
elif defined(macosx):
    const width = 700
    const height = 450
    const minWidth = 650
    const minHeight = 400

let hdir = os.getEnv("HOME")
# var app {.threadvar.}: Webview
let app = newWebView(currentHtmlPath("views/index.html"),
    debug=true,
    title="nodecliac GUI",
    width=width, height=height,
    minWidth=minWidth, minHeight=minHeight,
    resizable=true,
    cssPath=currentHtmlPath("css/empty.css") # [Bug] Line doesn't work on macOS?
)

# import ./nevents
# import ./observable

# type
#   ObserveObject = ref object
#     `mod`: int
#     commands: seq[string]
# var oobject {.threadvar.}: ObserveObject
# oobject = ObserveObject()
# oobject.onChange(x=>x.commands, proc (x: ObserveObject) =
#     echo "[ObserveChange]"
# )
# handleObserver()
# oobject.commands.add("FIRST")
# handleObserver()

# # let appptr = addr app

# var list {.threadvar.}: seq[int]
# list = @[1, 2, 3, 4]

# proc poller() {.async.} =
#     var counter = 0
#     while true:
#         inc(counter)
#         echo "<" & $counter & ">"
#         await sleepAsync(1000)
#         echo "DONE"

# asyncCheck poller()


# type args = object of EventArgs
#     name: string
# var events {.threadvar.}: EventEmitter
# events = initEventEmitter()
# events.on("foo", proc (a: EventArgs) {.gcsafe.} =
#     echo "INSIDE FUNCTION MAIN"
#     var b = args(a)
#     assert b.name == "Fox!"
#     # app.js("console.log('12');document.body.style.display = 'none';")
#     app.js("console.log('12');")

#     list.add(10)
#     echo list

#     # app.dispatch(
#     #     proc () {.gcsafe.} =
#     #         echo "????????//"
#     #         app.js("console.log('12');")
#     # )
# )
# events.emit("foo", args(name: "Fox!"))


# # var thread_t_watcher: Thread[void]
# # var thread_t_watcher: Thread[ptr seq[string]]
# # var thread_t_watcher: Thread[ptr ObserveObject]
# var thread_t_watcher: Thread[ptr EventEmitter]
# #
# import ./fsmonitor2
# # var dircommands {.threadvar.}: seq[string]
# # dircommands = @[]
# # proc thread_a_watcher(oo: ptr ObserveObject) {.thread.} =
# proc thread_a_watcher(e: ptr EventEmitter) {.thread.} =
#     # echo "LENGTH[1]: [", oo[].commands.len, "]"
#     # handleObserver()
#     # oo[].commands.add("SECOND")
#     # handleObserver()
#     # echo "LENGTH[2]: [", oo[].commands.len, "]"

#     # [https://bugs.webkit.org/show_bug.cgi?id=175855]
#     # e[].emit("foo", args(name: "Fox!"))

#     let hdir = os.getEnv("HOME")
#     var monitor = newMonitor()
#     discard monitor.add(hdir & "/.nodecliac/registry/", {
#         MonitorCreate,
#         MonitorDelete,
#         MonitorDeleteSelf,
#         MonitorModify,
#         MonitorMoved
#     })
#     monitor.register(
#         proc (ev: MonitorEvent) {.gcsafe.} =
#             # echo("Got event: ", ev.kind)
#             # if ev.kind == MonitorMoved:
#             #     echo("From ", ev.oldPath, " to ", ev.newPath)
#             #     echo("Name is ", ev.name)
#             # else:
#             #     echo("Name ", ev.name, " fullname ", ev.fullName)
#             echo("Got event: ", ev.kind, " Name ", ev.name, " fullname ", ev.fullName)
#     )

#     monitor.watch()
#     runForever()

# # createThread(thread_t_watcher, thread_a_watcher, addr oobject)
# createThread(thread_t_watcher, thread_a_watcher, addr events)

# # [https://github.com/paul-nameless/nim-fswatch]
# import libfswatch
# import libfswatch/fswatch

# type
#     FileTimeMods = object
#         config, registry: int

# var ftmods {.threadvar.}: FileTimeMods
# ftmods = FileTimeMods(config: 0, registry: 0)

# # [https://gist.github.com/PixeyeHQ/fbec35b25b667b847b4eac413a8539a5]
# # [https://nim-lang.org/docs/iterators.html#fieldPairs.i%2CT]
# proc thread_a_watcher() {.thread.} =
#     echo "Watching....."
#     proc callback(event: fsw_cevent, event_num: cuint) =

#         let p = $(event.path)
#         let s = "config"
#         if s in p:
#             echo "CONFIG"
#             echo ">>>>>>>>>>>>>> [", ftmods.config , "]"
#             # inc(ftmods.config)
#             # inc(ftmods.registry)
#             ftmods.config = event.time_t
#             echo "path: [", event.path, " ~> ", $(event.flags[]), "] ==== [", event_num, "]"
#             echo "time_t: [", event.time_t, "] ==== [", event_num, "]"
#             echo "flags: [", event.flags[], "] ==== [", event_num, "]"
#             echo "flags_num: [", event.flags_num, "] ==== [", event_num, "]"
#             echo ""
#         else:
#             echo "REGISTRY"
#             echo ">>>>>>>>>>>>>> [", ftmods.registry , "]"
#             ftmods.registry = event.time_t
#             echo "path: [", event.path, " ~> ", $(event.flags[]), "] ==== [", event_num, "]"
#             echo "time_t: [", event.time_t, "] ==== [", event_num, "]"
#             echo "flags: [", event.flags[], "] ==== [", event_num, "]"
#             echo "flags_num: [", event.flags_num, "] ==== [", event_num, "]"
#             echo ""

#     let hdir = os.getEnv("HOME")
#     var mon = newMonitor()
#     mon.addPath(hdir & "/.nodecliac/registry/")
#     mon.addPath(hdir & "/.nodecliac/.config")
#     mon.setCallback(callback)
#     mon.start()

# createThread(thread_t_watcher, thread_a_watcher)

# Run package manager actions (i.e. updating/remove/adding packages)
# on its own thread to prevent blocking main UI/WebView event loop.
proc thread_a_update(chan: ptr Channel[ChannelMsg]) {.thread.} =
    # [https://github.com/dom96/nim-in-action-code/blob/master/Chapter3/ChatApp/src/client.nim#L42-L50]
    while true:
        var incoming = chan[].recv()
        if not incoming.future[].finished:
            var response: Response
            response = Response(code: -1)

            # Get user name: [https://stackoverflow.com/a/23931327]
            let uname = execProcess("id -u -n").strip(trailing=true)

            # Ask user for password.
            let input = dialogInput(
                aTitle = "Authentication Required",
                aMessage = fmt"Authentication required to update nodecliac, please enter your password.\n\nPassword for {uname}:",
                aDefaultInput = nil,
                aIconType = "info"
            )

            # If password provided validate it's correct.
            if input.len != 0:
                # [https://askubuntu.com/a/622419]
                # [http://www.yourownlinux.com/2015/08/how-to-check-if-username-and-password-are-valid-using-bash-script.html]
                let script = fmt"""#! /bin/bash
sudo -k
if sudo -lS &> /dev/null << EOF
{input}
EOF
then
{incoming.cmd}
else
exit 1
fi"""
                let cmd = fmt"""bash -c '{script}'"""
                let (res, code) = execCmdEx(cmd)

                if code == 1: response.resp = "val:fail"
                response.code = code

            incoming.future[].complete(response)
            # sleep 3000 # [https://github.com/nim-lang/Nim/issues/3687]

# Run package manager actions (i.e. updating/remove/adding packages)
# on its own thread to prevent blocking main UI/WebView event loop.
proc thread_a_doctor(chan: ptr Channel[ChannelMsg]) {.thread.} =
    # [https://github.com/dom96/nim-in-action-code/blob/master/Chapter3/ChatApp/src/client.nim#L42-L50]
    while true:
        var incoming = chan[].recv()
        if not incoming.future[].finished:
            var response: Response
            response = Response(code: -1)

            let hdir = os.getEnv("HOME")
            let status = execProcess("nodecliac").strip(trailing=true)
            let ping =
                if status.len == 0: "<div class=\"value\">OK</div>"
                else: "<div class=\"value error\">ERROR</div>"
            let version = execProcess("nodecliac --version").strip(trailing=true)
            let binary = execProcess("command -v nodecliac").strip(trailing=true)
            let binloc =
                if binary.startsWith(hdir): binary.replace(hdir, "~")
                else: binary

        # <div class=\"header\">Log</div>
            response.resp = fmt"""
        <div class=\"row\">
            <div class=\"label\">nodecliac ping:</div>
            {ping}
        </div>
        <div class=\"row\">
            <div class=\"label\">nodecliac -v:</div>
            <div class=\"value\">v{version}</div>
        </div>
        <div class=\"row\">
            <div class=\"label\">bin:</div>
            <div class=\"value\">{binloc}</div>
        </div>
        """.strip.unindent.multiReplace([("\n", " ")])

            incoming.future[].complete(response)

# Run package manager actions (i.e. updating/remove/adding packages)
# on its own thread to prevent blocking main UI/WebView event loop.
proc thread_a_ccache(chan: ptr Channel[ChannelMsg]) {.thread.} =
    # [https://github.com/dom96/nim-in-action-code/blob/master/Chapter3/ChatApp/src/client.nim#L42-L50]
    while true:
        var incoming = chan[].recv()
        if not incoming.future[].finished:
            var response: Response
            response = Response(code: -1)

            # Use nodecliac CLI.
            # discard execProcess("nodecliac cache --clear")

            # Nim native `nodecliac cache --clear` equivalent...
            let hdir = os.getEnv("HOME")
            let cp = hdir & "/.nodecliac/.cache"
            if dirExists(cp):
                for kind, path in walkDir(cp):
                    if kind == pcFile: discard tryRemoveFile(path)

            incoming.future[].complete(response)

# Run package manager actions (i.e. updating/remove/adding packages)
# on its own thread to prevent blocking main UI/WebView event loop.
proc thread_a_actions1(chan: ptr Channel[ChannelMsg]) {.thread.} =
    # [https://github.com/dom96/nim-in-action-code/blob/master/Chapter3/ChatApp/src/client.nim#L42-L50]
    while true:
        var incoming = chan[].recv()
        if not incoming.future[].finished:
            var response: Response
            response = Response(code: -1)

            let action = incoming.action
            let all = incoming.all
            case action:
                of "get-packages":

                    # var empty = true
                    let hdir = os.getEnv("HOME")
                    var items: seq[tuple[name, version: string, disabled: bool]] = @[]
                    let dirtypes = {pcDir, pcLinkToDir}
                    for kind, path in walkDir(hdir & "/.nodecliac/registry"):
                        # [https://nim-lang.org/docs/os.html#PathComponent]
                        # Only get dirs/links to dirs
                        if kind notin dirtypes: continue

                        # empty = false
                        let parts = splitPath(path)
                        let command = parts.tail
                        var version = "0.0.1"
                        var disabled = false

                        # Get version.
                        let config = joinPath(path, "package.ini")
                        if fileExists(config):
                            let data = loadConfig(config)
                            version = data.getSectionValue("Package", "version")

                        # Get disabled state.
                        let dconfig = joinPath(path, fmt".{command}.config.acdef")
                        if fileExists(dconfig):
                            let contents = readFile(dconfig)
                            if find(contents, re("@disable\\s=\\strue")) > -1:
                                disabled = true

                        var item: tuple[name, version: string, disabled: bool]
                        item = (name: command, version: version, disabled: disabled)
                        items.add(item)

                     # [https://stackoverflow.com/a/6712058]
                    proc alphasort(a, b: tuple[name, version: string, disabled: bool]): int =
                        let aname = a.name.toLower()
                        let bname = b.name.toLower()
                        if aname < bname: result = -1 # Sort string ascending.
                        elif aname > bname: result = 1
                        else: result = 0 # Default return value (no sorting).
                    items.sort(alphasort)

                    response.names = addr items

                else: discard

            incoming.future[].complete(response)

# Run package manager actions (i.e. updating/remove/adding packages)
# on its own thread to prevent blocking main UI/WebView event loop.
proc thread_a_actions2(chan: ptr Channel[ChannelMsg]) {.thread.} =
    # [https://github.com/dom96/nim-in-action-code/blob/master/Chapter3/ChatApp/src/client.nim#L42-L50]
    while true:
        var incoming = chan[].recv()
        if not incoming.future[].finished:
            var response: Response
            response = Response(code: -1)

            let action = incoming.action
            let all = incoming.all
            case action:
                of "get-packages-avai":

                    let pkg = readFile(currentSourcePath().splitPath.head / "packages.json")
                    let jdata = parseJSON(pkg)
                    var items: seq[tuple[name, version: string, disabled: bool]] = @[]
                    for item in items(jdata):
                        let pname = item["name"].getStr()
                        let prepo = item["repo"].getStr()
                        let pmethod = item["method"].getStr()
                        let pdescription = item["description"].getStr()
                        let plicense = item["license"].getStr()
                        if item.hasKey("tags"):
                            let ptags = item["tags"]
                            for t in items(ptags):
                                let t = t.getStr()

                        # https://raw.githubusercontent.com/cgabriel5/nodecliac/master/package.json
                        # https://raw.githubusercontent.com/nim-lang/nimble/master/packages.json
                        # https://github.com/nim-lang/nimble

                        var item: tuple[name, version: string, disabled: bool]
                        item = (name: pname, version: "", disabled: false)
                        items.add(item)

                    # [https://stackoverflow.com/a/6712058]
                    proc alphasort(a, b: tuple[name, version: string, disabled: bool]): int =
                        let aname = a.name.toLower()
                        let bname = b.name.toLower()
                        if aname < bname: result = -1 # Sort string ascending.
                        elif aname > bname: result = 1
                        else: result = 0 # Default return value (no sorting).
                    items.sort(alphasort)

                    response.names = addr items

                    # # var empty = true
                    # let hdir = os.getEnv("HOME")
                    # var items: seq[tuple[name, version: string, disabled: bool]] = @[]
                    # let dirtypes = {pcDir, pcLinkToDir}
                    # for kind, path in walkDir(hdir & "/.nodecliac/registry"):
                    #     # [https://nim-lang.org/docs/os.html#PathComponent]
                    #     # Only get dirs/links to dirs
                    #     if kind notin dirtypes: continue

                    #     # empty = false
                    #     let parts = splitPath(path)
                    #     let command = parts.tail
                    #     var version = "0.0.1"
                    #     var disabled = false

                    #     # Get version.
                    #     let config = joinPath(path, "package.ini")
                    #     if fileExists(config):
                    #         let data = loadConfig(config)
                    #         version = data.getSectionValue("Package", "version")

                    #     # Get disabled state.
                    #     let dconfig = joinPath(path, fmt".{command}.config.acdef")
                    #     if fileExists(dconfig):
                    #         let contents = readFile(dconfig)
                    #         if find(contents, re("@disable\\s=\\strue")) > -1:
                    #             disabled = true

                    #     var item: tuple[name, version: string, disabled: bool]
                    #     item = (name: command, version: version, disabled: disabled)
                    #     items.add(item)

                    #  # [https://stackoverflow.com/a/6712058]
                    # proc alphasort(a, b: tuple[name, version: string, disabled: bool]): int =
                    #     let aname = a.name.toLower()
                    #     let bname = b.name.toLower()
                    #     if aname < bname: result = -1 # Sort string ascending.
                    #     elif aname > bname: result = 1
                    #     else: result = 0 # Default return value (no sorting).
                    # items.sort(alphasort)

                    # response.names = addr items

                else: discard

            incoming.future[].complete(response)

# Run package manager actions (i.e. updating/remove/adding packages)
# on its own thread to prevent blocking main UI/WebView event loop.
proc thread_a_actions3(chan: ptr Channel[ChannelMsg]) {.thread.} =
    # [https://github.com/dom96/nim-in-action-code/blob/master/Chapter3/ChatApp/src/client.nim#L42-L50]
    while true:
        var incoming = chan[].recv()
        if not incoming.future[].finished:
            var response: Response
            response = Response(code: -1)

            let action = incoming.action
            let all = incoming.all
            case action:
                of "get-packages-out":

                    # get commands
                    # get each packages repo url information
                    #   - make repo url for each command
                    # make http reqs to compare remote version
                    #   ... with local version

                    # var urls: seq[string] = @[]
                    # let urls = array[items.len, string]
                    var urls = initTable[string, string]()

                    # var empty = true
                    let hdir = os.getEnv("HOME")
                    var items: seq[tuple[name, version: string, disabled: bool]] = @[]
                    let dirtypes = {pcDir, pcLinkToDir}
                    for kind, path in walkDir(hdir & "/.nodecliac/registry"):
                        # [https://nim-lang.org/docs/os.html#PathComponent]
                        # Only get dirs/links to dirs
                        if kind notin dirtypes: continue

                        # empty = false
                        let parts = splitPath(path)
                        let command = parts.tail
                        var version = "0.0.1"
                        var disabled = false

                        var url = ""

                        # Get version.
                        let config = joinPath(path, "package.ini")
                        if fileExists(config):
                            let data = loadConfig(config)
                            version = data.getSectionValue("Package", "version")

                            var repo = data.getSectionValue("Author", "repo")
                            repo.removePrefix({'/'})
                            var sub = data.getSectionValue("Author", "sub", "")
                            sub.removePrefix({'/'})
                            sub.removeSuffix({'/'})

                            if repo != "":
                                let uparts = parseUri(repo)
                                var path = uparts.path
                                path.removePrefix({'/'})
                                let parts = splitPath(path)
                                let username = parts[0]
                                let reponame = parts[1]

                                url = fmt"https://raw.githubusercontent.com/{username}/{reponame}/master"
                                if sub != "": url &= fmt"/{sub}"
                                # url &= "/package.ini"
                                url &= fmt"/{command}.acmap"

                        urls[command] = url

                        # # Get disabled state.
                        # let dconfig = joinPath(path, fmt".{command}.config.acdef")
                        # if fileExists(dconfig):
                        #     let contents = readFile(dconfig)
                        #     if find(contents, re("@disable\\s=\\strue")) > -1:
                        #         disabled = true

                        var item: tuple[name, version: string, disabled: bool]
                        item = (name: command, version: version, disabled: disabled)
                        items.add(item)

                     # [https://stackoverflow.com/a/6712058]
                    proc alphasort(a, b: tuple[name, version: string, disabled: bool]): int =
                        let aname = a.name.toLower()
                        let bname = b.name.toLower()
                        if aname < bname: result = -1 # Sort string ascending.
                        elif aname > bname: result = 1
                        else: result = 0 # Default return value (no sorting).
                    items.sort(alphasort)

                    response.names = addr items

                    # ==========================================================
                    # ==========================================================
                    # ==========================================================

                    # [https://nim-lang.org/docs/tut2.html#exceptions-try-statement]
                    proc fetchfile(url: string): Future[string] {.async.} =
                        let client = newAsyncHttpClient()
                        let resp = await get(client, url)

                        if not resp.code.is2xx:
                            let f = newFuture[string]("fetchfile.nodecliac")
                            f.complete("[ERR: " & $(resp.code) & "]")
                            return await f
                        else:
                            return await resp.bodyStream.readAll()

                    var outdated: seq[tuple[name, local_version, remote_version: string, config: OrderedTableRef[string, OrderedTableRef[string, string]]]] = @[]

                    proc testhttp {.async.} =
                        # var reqs: array[urls.len, Future[string]]
                        var reqs: seq[Future[string]]
                        # for i, url in urls: reqs[i] = fetchfile(url)
                        # for url in urls: reqs.add(fetchfile(url))
                        # for command, url in urls.pairs:
                            # reqs.add(fetchfile(url))
                        for item in items:
                            reqs.add(fetchfile(urls[item.name]))
                        let reponses = await all(reqs)
                        for i, response in reponses:
                            # let strm = newStringStream(fmt"""{response}""")
                            let strm = newStringStream(fmt"""[Package]
version = "0.0.2"
""")
                            let data = loadConfig(strm)
                            let remote_version = data.getSectionValue("Package", "version")
                            let local_version = items[i].version;

                            if  local_version != remote_version:
                                var item: tuple[name, local_version, remote_version: string, config: OrderedTableRef[string, OrderedTableRef[string, string]]]
                                item = (
                                    name: items[i].name,
                                    local_version: local_version,
                                    remote_version: remote_version,
                                    config: data
                                )
                                outdated.add(item)

                        response.outdated = addr outdated
                        incoming.future[].complete(response)

                    waitFor testhttp()

                    # # var empty = true
                    # let hdir = os.getEnv("HOME")
                    # var items: seq[tuple[name, version: string, disabled: bool]] = @[]
                    # let dirtypes = {pcDir, pcLinkToDir}
                    # for kind, path in walkDir(hdir & "/.nodecliac/registry"):
                    #     # [https://nim-lang.org/docs/os.html#PathComponent]
                    #     # Only get dirs/links to dirs
                    #     if kind notin dirtypes: continue

                    #     # empty = false
                    #     let parts = splitPath(path)
                    #     let command = parts.tail
                    #     var version = "0.0.1"
                    #     var disabled = false

                    #     # Get version.
                    #     let config = joinPath(path, "package.ini")
                    #     if fileExists(config):
                    #         let data = loadConfig(config)
                    #         version = data.getSectionValue("Package", "version")

                    #     # Get disabled state.
                    #     let dconfig = joinPath(path, fmt".{command}.config.acdef")
                    #     if fileExists(dconfig):
                    #         let contents = readFile(dconfig)
                    #         if find(contents, re("@disable\\s=\\strue")) > -1:
                    #             disabled = true

                    #     var item: tuple[name, version: string, disabled: bool]
                    #     item = (name: command, version: version, disabled: disabled)
                    #     items.add(item)

                    #  # [https://stackoverflow.com/a/6712058]
                    # proc alphasort(a, b: tuple[name, version: string, disabled: bool]): int =
                    #     let aname = a.name.toLower()
                    #     let bname = b.name.toLower()
                    #     if aname < bname: result = -1 # Sort string ascending.
                    #     elif aname > bname: result = 1
                    #     else: result = 0 # Default return value (no sorting).
                    # items.sort(alphasort)

                    # response.names = addr items

                else: discard

            incoming.future[].complete(response)

# Run package manager actions (i.e. updating/remove/adding packages)
# on its own thread to prevent blocking main UI/WebView event loop.
proc thread_a_actions(chan: ptr Channel[ChannelMsg]) {.thread.} =
    # [https://github.com/dom96/nim-in-action-code/blob/master/Chapter3/ChatApp/src/client.nim#L42-L50]
    while true:
        var incoming = chan[].recv()
        if not incoming.future[].finished:
            var response: Response
            response = Response(code: -1)

            let action = incoming.action
            let all = incoming.all

            case action:
                of "remove":
                    # Use nodecliac CLI.
                    # let names = incoming.list[]
                    # var cmd = fmt"""nodecliac remove"""
                    # for name in names: cmd &= " " & name
                    # discard execProcess(cmd)

                    let hdir = os.getEnv("HOME")
                    let names = incoming.list[]
                    for name in names:
                        let p = hdir & "/.nodecliac/registry/" & name
                        # if dirExists(p): removeDir(p)
                of "enable":
                    # Use nodecliac CLI.
                    # [https://forum.nim-lang.org/t/6122]
                    let names = (
                        if not all:
                            incoming.list[]
                        else:
                            # If all flag is set, get all registry package names.
                            var names: seq[string] = @[]
                            let hdir = os.getEnv("HOME")
                            for kind, path in walkDir(hdir & "/.nodecliac/registry"):
                                let parts = splitPath(path)
                                names.add(parts.tail)
                            names.sort()
                            names
                    )
                    var cmd = fmt"""nodecliac enable"""
                    for name in names: cmd &= " " & name
                    discard execProcess(cmd)
                of "disable":
                    # Use nodecliac CLI.
                    let names = (
                        if not all:
                            incoming.list[]
                        else:
                            # If all flag is set, get all registry package names.
                            var names: seq[string] = @[]
                            let hdir = os.getEnv("HOME")
                            for kind, path in walkDir(hdir & "/.nodecliac/registry"):
                                let parts = splitPath(path)
                                names.add(parts.tail)
                            names.sort()
                            names
                    )
                    var cmd = fmt"""nodecliac disable"""
                    for name in names: cmd &= " " & name
                    discard execProcess(cmd)

                else: discard

            incoming.future[].complete(response)

proc main() =

    # when defined(linux):
    #     const width = 1100
    #     const height = 750
    #     const minWidth = 950
    #     const minHeight = 600
    # elif defined(macosx):
    #     const width = 700
    #     const height = 450
    #     const minWidth = 650
    #     const minHeight = 400

    # let hdir = os.getEnv("HOME")
    # let app = newWebView(currentHtmlPath("views/index.html"),
    #     debug=true,
    #     title="nodecliac GUI",
    #     width=width, height=height,
    #     minWidth=minWidth, minHeight=minHeight,
    #     resizable=true,
    #     cssPath=currentHtmlPath("css/empty.css") # [Bug] Line doesn't work on macOS?
    # )

    proc updater() {.async.} =

        app.js("""
            document.getElementById("update-spinner").classList.remove("none");
            document.getElementById("update-update").classList.add("nointer", "disabled");
            """)

        let filename = currentSourcePath()
        let cwd = parentDir(filename)
        # let prev = parentDir(parentDir(filename))
        let script = joinPath(cwd, "updater.sh")
        # let cmd = fmt"""bash -c '{script}'"""
        let cmd = script

        var chan: Channel[ChannelMsg]
        chan.open()
        var thread: Thread[ptr Channel[ChannelMsg]]
        createThread(thread, thread_a_update, addr chan)

        var fut = newFuture[Response]("update.nodecliac")
        let data = ChannelMsg(future: addr fut, cmd: cmd, action: "update")
        chan.send(data)
        let r = await fut
        chan.close()

        let date = getTime()
        # [https://nim-lang.org/docs/times.html#parsing-and-formatting-dates]
        let datestring = date.format("MMM'.' d, yyyy (h:mm tt)")
        var title, message, icon, class: string
        case r.code
            of 1:
                title = "Error"
                message = "Authentication attempt failed (incorrect password provided)."
                icon = "fas fa-times-circle"
                class = "error"
            of -1:
                title = "Aborted"
                message = "nodecliac update aborted."
                icon = "fas fa-exclamation-circle"
                class = "aborted"
            else:
                title = "Success"
                message = "nodecliac updated successfully."
                icon = "fas fa-check-circle"
                class = "success"
        let logrow = fmt"""
<div class="logitem row new-highlight {class}">
<div class="logitem-top">
    <div class="left center">
        <div class="icon">
            <i class="{icon}"></i>
        </div>
        <div class="title">{title}</div>
    </div>
    <div class="right">
        <div class="time">
            {datestring}
        </div>
    </div>
</div>
<div>{message}</div>
</div>""".strip.unindent.multiReplace([("\n", " ")])
        app.dispatch(
            proc () =
                app.js(fmt"""document.getElementById('update-output').insertAdjacentHTML('afterbegin', `{logrow}`);""")
        )

        # [https://bugs.webkit.org/show_bug.cgi?id=175855]
        app.dispatch(
            proc () =
                # echo "[FutureValue] [", fut[].code.read, "]"
                # echo "[FutureValue] [", fut[].resp.read, "]"
                app.js(fmt"""
            document.getElementById("update-update").classList.remove("nointer", "disabled");
            document.getElementById("update-spinner").classList.add("none");
            """)
        )

        # let filename = currentSourcePath()
        # let cwd = parentDir(filename)
        # let prev = parentDir(parentDir(filename))
        # let script = joinPath(cwd, "updater.sh")
        # when defined(linux):
        #     # [https://askubuntu.com/a/1105741]
        #     # [https://stackoverflow.com/a/29689199]
        #     # [https://stackoverflow.com/a/3980713]
        #     # let cmd = fmt"""bash -c 'echo "nodecliac\ updater:";sudo sh -c "" > /dev/null 2>&1; bash <(cat "{script}") --update --packages --yes; $SHELL'"""
        #     let cmd = fmt"""gnome-terminal --command="bash -c '{script}; $SHELL'""""
        # elif defined(macosx):
        #     let ascript = joinPath(cwd, "updater.scpt")
        #     # osascript /opt/lampp/htdocs/projects/nodecliac/gui/updater.scpt /opt/lampp/htdocs/projects/nodecliac/install.sh
        #     let cmd = fmt"""osascript {ascript} {script} --macosx"""
        # discard execCmdEx(cmd)

    proc checkup() {.async.} =

        app.js("""
            document.getElementById("doctor-spinner").classList.remove("none");
            document.getElementById("doctor-run").classList.add("nointer", "disabled");
            """)

        var chan: Channel[ChannelMsg]
        chan.open()
        var thread: Thread[ptr Channel[ChannelMsg]]
        createThread(thread, thread_a_doctor, addr chan)

        var fut = newFuture[Response]("doctor.nodecliac")
        let data = ChannelMsg(future: addr fut, action: "doctor")
        chan.send(data)
        let r = await fut
        let html = r.resp
        chan.close()

        app.dispatch(
            proc () =
                app.js(fmt"""
                document.getElementById("doctor-output").innerHTML = `{html}`;
                document.getElementById("doctor-run").classList.remove("nointer", "disabled");
                document.getElementById("doctor-spinner").classList.add("none");
                """)
        )

    proc enapkgs(s: string) {.async.} =
        let jdata = parseJSON(s)
        let all = jdata["all"].getBool()
        let panel = jdata["panel"].getStr()

            # document.getElementById("doctor-run").classList.add("nointer", "disabled");
        app.js(fmt"""
            get_panel_by_name("{panel}").$tb_loader.classList.remove("none");
            """)

        var names: seq[string] = @[]
        for item in items(jdata["names"]):
            let name = item.getStr()
            if name != "nodecliac": names.add(name)

        var chan: Channel[ChannelMsg]
        chan.open()
        var thread: Thread[ptr Channel[ChannelMsg]]
        createThread(thread, thread_a_actions, addr chan)

        var fut = newFuture[Response]("enapkgs.nodecliac")
        let data = ChannelMsg(future: addr fut, action: "enable", list: addr names, all: all)
        chan.send(data)
        let r = await fut
        let html = r.resp
        chan.close()

        var remcmd = ""
        for name in names:
            remcmd &= fmt"""var $status = f("#pkg-entry-{name}").all().classes("pstatus").getElement();
var classes = $status.classList;
classes.remove("off");
classes.add("on");"""

        if all:
            remcmd = fmt"""
            var PANEL = get_panel_by_name("{panel}");
            var $statuses = f(PANEL.$entries).all().classes("pstatus").getStack();
            $statuses.forEach(function(x, i) {{
                let classes = x.classList;
                classes.remove("off");
                classes.add("on");
            }});
            """

        app.dispatch(
            proc () =
                app.js(fmt"""
                {remcmd}
                get_panel_by_name("{panel}").$tb_loader.classList.add("none");
                processes.packages.{panel} = false;
                """)
        )

                # document.getElementById("doctor-output").innerHTML = `{html}`;
                # document.getElementById("doctor-run").classList.remove("nointer", "disabled");

    proc dispkgs(s: string) {.async.} =
        let jdata = parseJSON(s)
        let all = jdata["all"].getBool()
        let panel = jdata["panel"].getStr()

            # document.getElementById("doctor-run").classList.add("nointer", "disabled");
            # document.getElementById("pkg-action-spinner").classList.remove("none");
        app.js(fmt"""
            get_panel_by_name("{panel}").$tb_loader.classList.remove("none");
            """)

        var names: seq[string] = @[]
        for item in items(jdata["names"]):
            let name = item.getStr()
            if name != "nodecliac": names.add(name)

        var chan: Channel[ChannelMsg]
        chan.open()
        var thread: Thread[ptr Channel[ChannelMsg]]
        createThread(thread, thread_a_actions, addr chan)

        var fut = newFuture[Response]("dispkgs.nodecliac")
        let data = ChannelMsg(future: addr fut, action: "disable", list: addr names, all: all)
        chan.send(data)
        let r = await fut
        let html = r.resp
        chan.close()

        var remcmd = ""
        for name in names:
            remcmd &= fmt"""var $status = f("#pkg-entry-{name}").all().classes("pstatus").getElement();
var classes = $status.classList;
classes.remove("on");
classes.add("off");"""

        if all:
            remcmd = fmt"""
            var PANEL = get_panel_by_name("{panel}");
            var $statuses = f(PANEL.$entries).all().classes("pstatus").getStack();
            $statuses.forEach(function(x, i) {{
                let classes = x.classList;
                classes.remove("on");
                classes.add("off");
            }});
            """

        app.dispatch(
            proc () =
                app.js(fmt"""
                {remcmd}
                get_panel_by_name("{panel}").$tb_loader.classList.add("none");
                processes.packages.{panel} = false;
                """)
        )

                # document.getElementById("doctor-output").innerHTML = `{html}`;
                # document.getElementById("doctor-run").classList.remove("nointer", "disabled");

    proc rempkgs(s: string) {.async.} =
        let jdata = parseJSON(s)
        let panel = jdata["panel"].getStr()

            # document.getElementById("doctor-run").classList.add("nointer", "disabled");
            # document.getElementById("tb-actions").classList.add("disabled");
        app.js(fmt"""
            get_panel_by_name("{panel}").$tb_loader.classList.remove("none");
            """)

        var names: seq[string] = @[]
        for item in items(jdata["names"]):
            let name = item.getStr()
            if name != "nodecliac": names.add(name)

        var chan: Channel[ChannelMsg]
        chan.open()
        var thread: Thread[ptr Channel[ChannelMsg]]
        createThread(thread, thread_a_actions, addr chan)

        var fut = newFuture[Response]("rempkgs.nodecliac")
        let data = ChannelMsg(future: addr fut, action: "remove", list: addr names)
        chan.send(data)
        let r = await fut
        let html = r.resp
        chan.close()

        var remcmd = """var $parent = document.getElementById("pkg-entries");
        """
        for name in names:
            remcmd &= fmt"""var $child = document.getElementById("pkg-entry-{name}");
$parent.removeChild($child);"""

        app.dispatch(
            proc () =
                app.js(fmt"""
                {remcmd}
                get_panel_by_name("{panel}").$tb_loader.classList.add("none");
                processes.packages.{panel} = false;
                """)
        )
                # document.getElementById("tb-actions").classList.remove("disabled");

                # document.getElementById("doctor-output").innerHTML = `{html}`;
                # document.getElementById("doctor-run").classList.remove("nointer", "disabled");

    proc config_update(setting: string, value: int) =
        let p =  hdir & "/.nodecliac/.config"
        var config = if fileExists(p): readFile(p) else: ""
        var index = case setting
            of "status": 0
            of "cache": 1
            of "debug": 2
            else: 3

        if config != "":
            config[index] = ($(value))[0]
            writeFile(p, config)

    proc settings_reset() =
        writeFile(hdir & "/.nodecliac/.config", "1001")
        app.js(fmt"window.api.setup_config(1,0,0,1);")
    proc setting_config_state(state: int) = config_update("status", state)
    proc setting_config_cache(state: int) = config_update("cache", state)
    proc setting_config_debug(state: int) = config_update("debug", state)
    proc setting_config_singletons(state: int) = config_update("singletons", state)

    proc settings_clear_cache() {.async.} =

        app.js("""
            document.body.classList.add("nointer");
            document.getElementById("loader").classList.remove("none");
            setTimeout(function() {
                document.getElementById("loader").classList.add("opa1");
            }, 10);
        """)

        var chan: Channel[ChannelMsg]
        chan.open()
        var thread: Thread[ptr Channel[ChannelMsg]]
        createThread(thread, thread_a_ccache, addr chan)

        var fut = newFuture[Response]("clear-cache.nodecliac")
        let data = ChannelMsg(future: addr fut)
        chan.send(data)
        let r = await fut
        chan.close()

        app.dispatch(
            proc () =
                app.js("""
                    setTimeout(function() {
                        document.getElementById("loader").classList.add("opa1");
                        setTimeout(function() {
                            document.getElementById("loader").classList.add("none");
                            document.body.classList.remove("nointer");
                        }, 10);
                    }, 250);
                """)
        )

    proc get_config() =
        let p =  hdir & "/.nodecliac/.config"
        let config = if fileExists(p): readFile(p) else: ""
        # if config != "":
            # app.js("setup_config(" & config & ")")
        if config != "":
            let status = config[0]
            let cache = config[1]
            let debug = config[2]
            let singletons = config[3]
            app.js(fmt"window.api.setup_config({status},{cache},{debug},{singletons});")
            # jsLog(config)

    # var names: seq[string] = @[]
    # for kind, path in walkDir(hdir & "/.nodecliac/registry"):
    #     let parts = splitPath(path)
    #     names.add(parts.tail)
    # names.sort()

    var names: seq[tuple[name, version: string, disabled: bool]] = @[]

    proc filter_pkgs(s: string) =
        # Remove nodes: [https://stackoverflow.com/a/3955238]
        # Fragment: [https://howchoo.com/code/learn-the-slow-and-fast-way-to-append-elements-to-the-dom]
        # Fuzzy search:
        # [https://github.com/nim-lang/Nim/issues/13955]
        # [https://github.com/nim-lang/Nim/blob/devel/tools/dochack/dochack.nim]
        # [https://github.com/nim-lang/Nim/blob/devel/tools/dochack/fuzzysearch.nim]
        # [https://www.forrestthewoods.com/blog/reverse_engineering_sublime_texts_fuzzy_match/]

        # var names: seq[string] = @[]
        # for kind, path in walkDir(hdir & "/.nodecliac/registry"):
        #     let parts = splitPath(path)
        #     names.add(parts.tail)
        # names.sort()

        var command = fmt"""
    // var $pkg_cont = document.getElementById("pkg-entries");
    var $pkg_cont = PKG_PANES_REFS.$entries;
    while ($pkg_cont.firstChild) $pkg_cont.removeChild($pkg_cont.lastChild);
    var $fragment = document.createDocumentFragment();
    """

        var empty = true

        for item in names:
            if s in item.name:
                empty = false
                let name_escaped = item.name.escape
                let classname = if item.disabled: "off" else: "on"
                command &= fmt"""
    var $entry = document.createElement("div");
    $entry.className = "entry";
    $entry.id = "pkg-entry-{name_escaped}";

    var $inner = document.createElement("div");
    $inner.className = "center";

    var $icon_cont = document.createElement("div");
    $icon_cont.className = "checkmark";
    $icon_cont.setAttribute("data-name", "{name_escaped}");
    var $icon = document.createElement("i");
    $icon.className = "fas fa-check none";
    $icon_cont.appendChild($icon);

    var $pstatus = document.createElement("div");
    $pstatus.className = "pstatus {classname}";

    // var $version = document.createElement("div");
    // $version.className = "version";
    // $version.textContent = "{item.version}";

    var $label = document.createElement("div");
    $label.className = "label";
    $label.textContent = "{name_escaped}";

    $inner.appendChild($icon_cont);
    $inner.appendChild($pstatus);
    // $inner.appendChild($version);
    $inner.appendChild($label);
    $entry.appendChild($inner);
    $fragment.appendChild($entry);
    """

        if empty:
            command &= """
            var $entry = document.createElement("div");
            $entry.className = "empty";

            var $child = document.createElement("div");
            $child.textContent = "No Packages";

            $entry.appendChild($child);
            $fragment.appendChild($entry);
            """

        command &= """
    $pkg_cont.appendChild($fragment);
    f(PKG_PANES_REFS.$cont).all().classes("search-loader").getElement().classList.add("none");
    // document.getElementById("search-loader").classList.add("none");
    """

        app.js(command)

    proc get_packages_outd(j: string) {.async.} =
        let jdata = parseJSON(j)
        let s = jdata["input"].getStr()
        let panel = jdata["panel"].getStr()

        app.js(fmt"""
            var PANEL = get_panel_by_name("{panel}");
            PANEL.$sbentry.classList.remove("none");
        """)

        var chan: Channel[ChannelMsg]
        chan.open()
        var thread: Thread[ptr Channel[ChannelMsg]]
        createThread(thread, thread_a_actions3, addr chan)

        var fut = newFuture[Response]("get-packages-out.nodecliac")
        let data = ChannelMsg(future: addr fut, action: "get-packages-out")
        chan.send(data)
        let r = await fut
        var items = r.outdated[]
        names = r.names[]
        chan.close()

        var html = ""
        if items.len == 0:
            html &= """<div class="empty"><div>No Packages</div></div>"""
            app.dispatch(
                proc () =
                    app.js(
                        fmt"""
                        var PANEL = get_panel_by_name("{panel}");
                        PANEL.$entries.textContent = "";
                        PANEL.$entries.insertAdjacentHTML("afterbegin", `{html}`);
                        """
                    )
            )
        else:
            for item in items:
                if s != "":
                    if s notin item.name: continue
                # let classname = if item.disabled: "off" else: "on"
                html &= fmt"""<div class=entry id=pkg-entry-{item.name}>
                    <div class="center">
                        <div class="checkmark" data-name="{item.name}">
                            <i class="fas fa-check none"></i>
                        </div>
                        <div class="label">{item.name}</div>
                    </div>
                </div>""".strip.unindent.multiReplace([("\n", " ")])
                        # <div class="pstatus {classname}"></div>
                        # <div class="version">{item.version}</div>

            app.dispatch(
                proc () =
                    app.js(
                        fmt"""
                        var PANEL = get_panel_by_name("{panel}");
                        PANEL.$entries.textContent = "";
                        PANEL.$entries.insertAdjacentHTML("afterbegin", `{html}`);
                        """
                    )
            )

        app.dispatch(
            proc () =
                app.js(fmt"""
                    var PANEL = get_panel_by_name("{panel}");
                    PANEL.$sbentry.classList.add("none");
                    processes.packages["{panel}"] = false;
                """)
        )

    proc get_packages_avai(j: string) {.async.} =
        let jdata = parseJSON(j)
        let s = jdata["input"].getStr()
        let panel = jdata["panel"].getStr()

        app.js(fmt"""
            var PANEL = get_panel_by_name("{panel}");
            PANEL.$sbentry.classList.remove("none");
        """)

        var chan: Channel[ChannelMsg]
        chan.open()
        var thread: Thread[ptr Channel[ChannelMsg]]
        createThread(thread, thread_a_actions2, addr chan)

        var fut = newFuture[Response]("get-packages-avai.nodecliac")
        let data = ChannelMsg(future: addr fut, action: "get-packages-avai")
        chan.send(data)
        let r = await fut
        var items = r.names[]
        names = r.names[]
        chan.close()

        var html = ""
        if items.len == 0:
            html &= """<div class="empty"><div>No Packages</div></div>"""
            app.dispatch(
                proc () =
                    app.js(
                        fmt"""
                        var PANEL = get_panel_by_name("{panel}");
                        PANEL.$entries.textContent = "";
                        PANEL.$entries.insertAdjacentHTML("afterbegin", `{html}`);
                        """
                        # app.setText("#pkg-entries", "") & ";" &
                        # app.addHtml("#pkg-entries", html, position=afterbegin)
                    )
            )
        else:
            for item in items:
                if s != "":
                    if s notin item.name: continue
                let classname = if item.disabled: "off" else: "on"
                html &= fmt"""<div class=entry id=pkg-entry-{item.name}>
                    <div class="center">
                        <div class="checkmark" data-name="{item.name}">
                            <i class="fas fa-check none"></i>
                        </div>
                        <div class="label">{item.name}</div>
                    </div>
                </div>""".strip.unindent.multiReplace([("\n", " ")])
                        # <div class="pstatus {classname}"></div>
                        # <div class="version">{item.version}</div>

            app.dispatch(
                proc () =
                    app.js(
                        fmt"""
                        var PANEL = get_panel_by_name("{panel}");
                        PANEL.$entries.textContent = "";
                        PANEL.$entries.insertAdjacentHTML("afterbegin", `{html}`);
                        """
                        # app.setText("#pkg-entries", "") & ";" &
                        # app.addHtml("#pkg-entries", html, position=afterbegin)
                    )
            )

        app.dispatch(
            proc () =
                app.js(fmt"""
                    var PANEL = get_panel_by_name("{panel}");
                    PANEL.$sbentry.classList.add("none");
                    processes.packages["{panel}"] = false;
                """)
        )

    proc get_packages(j: string) {.async.} =
        let jdata = parseJSON(j)
        let s = jdata["input"].getStr()
        let panel = jdata["panel"].getStr()

        app.js(fmt"""
            var PANEL = get_panel_by_name("{panel}");
            PANEL.$sbentry.classList.remove("none");
        """)

        var chan: Channel[ChannelMsg]
        chan.open()
        var thread: Thread[ptr Channel[ChannelMsg]]
        createThread(thread, thread_a_actions1, addr chan)

        var fut = newFuture[Response]("get-packages.nodecliac")
        let data = ChannelMsg(future: addr fut, action: "get-packages")
        chan.send(data)
        let r = await fut
        var items = r.names[]
        names = r.names[]
        chan.close()

        var html = ""
        if items.len == 0:
            html &= """<div class="empty"><div>No Packages</div></div>"""
            app.dispatch(
                proc () =
                    app.js(
                        fmt"""
                        var PANEL = get_panel_by_name("{panel}");
                        PANEL.$entries.textContent = "";
                        PANEL.$entries.insertAdjacentHTML("afterbegin", `{html}`);
                        """
                        # app.setText("#pkg-entries", "") & ";" &
                        # app.addHtml("#pkg-entries", html, position=afterbegin)
                    )
            )
        else:
            for item in items:
                if s != "":
                    if s notin item.name: continue
                let classname = if item.disabled: "off" else: "on"
                html &= fmt"""<div class=entry id=pkg-entry-{item.name}>
                    <div class="center">
                        <div class="checkmark" data-name="{item.name}">
                            <i class="fas fa-check none"></i>
                        </div>
                        <div class="pstatus {classname}"></div>
                        <div class="label">{item.name}</div>
                    </div>
                </div>""".strip.unindent.multiReplace([("\n", " ")])
                        # <div class="version">{item.version}</div>

            app.dispatch(
                proc () =
                    app.js(
                        fmt"""
                        var PANEL = get_panel_by_name("{panel}");
                        PANEL.$entries.textContent = "";
                        PANEL.$entries.insertAdjacentHTML("afterbegin", `{html}`);
                        """
                        # app.setText("#pkg-entries", "") & ";" &
                        # app.addHtml("#pkg-entries", html, position=afterbegin)
                    )
            )

        app.dispatch(
            proc () =
                app.js(fmt"""
                    var PANEL = get_panel_by_name("{panel}");
                    PANEL.$sbentry.classList.add("none");
                    processes.packages.{panel} = false;
                """)
        )

    proc clink(url: string): string =
        return fmt"""
    <a class=\"link\"
        target=\"_blank\"
        onclick=\"api.open(this.href)\"
        href=\"{url}\">
        {url}
    </a>
    """.strip.unindent.multiReplace([("\n", " ")])

    proc flink(url: string): string =
        return fmt"""
    <a class=\"link\"
        onclick=\"api.fopen(this.textContent)\">
        {url}
    </a>
    """.strip.unindent.multiReplace([("\n", " ")])

    app.bindProcs("api"):
        # Open provided url in user's browser.
        #
        # @param  {string} url - The URL to open.
        # @return {nil} - Nothing is returned.
        proc open(url: string) =
            # [https://github.com/webview/webview/issues/113]
            openDefaultBrowser(url)

        # Open provided file in the OS's file explorer.
        #
        # @param  {string} url - The URL to open.
        # @return {nil} - Nothing is returned.
        proc fopen(path: string) =
            # [https://nim-lang.org/docs/osproc.html#execCmd%2Cstring]
            var path = path.strip(trailing=true)
            let p = hdir & "/.nodecliac/registry/" & splitPath(path).tail
            if path.startsWith('~'):
                path.removePrefix('~')
                path = hdir & path
            when defined(linux):
                const explorer = "xdg-open" # [https://superuser.com/a/465542]
            elif defined(macosx):
                const explorer = "open"
            # Ensure path matches registry path before running command.
            if path == p and dirExists(p): discard execCmd(explorer & " " & p)

        # Create a smaller window to show application about info.
        #
        # @return {nil} - Nothing is returned.
        proc about() =
            let about = newWebView(currentHtmlPath("views/about.html"),
                title="nodecliac GUI",
                width=600, height=350,
                resizable=false,
                cssPath=currentHtmlPath("css/about.css")
            )
            about.run()
            about.exit()

        proc get_pkg_info(s: string) =

            let jdata = parseJSON(s)
            let name = jdata["name"].getStr()
            let panel = jdata["panel"].getStr()

            # Check that package ini file exists.
            let config = hdir & "/.nodecliac/registry/" & name & "/package.ini"
            if fileExists(config):
                # Read the config file and get the needed data points.
                # [https://github.com/coffeepots/niminifiles]
                # [https://www.reddit.com/r/nim/comments/8gszys/nim_day_5_writing_ini_parser/]
                # [https://github.com/xmonader/nim-configparser]
                # [https://nim-lang.org/docs/parsecfg.html]
                let data = loadConfig(config)
                let name = data.getSectionValue("Package", "name".escape)
                let version = data.getSectionValue("Package", "version".escape)
                let description = data.getSectionValue("Package", "description".escape)
                let license = data.getSectionValue("Package", "license".escape)
                let author = data.getSectionValue("Author", "name".escape)
                let repo = clink(data.getSectionValue("Author", "repo").escape)
                let location = flink("~/.nodecliac/registry/" & name)

                app.js(fmt"""
                    window.api.set_pkg_info_row("{panel}", "name", "<span class='select'>{name}</span>");
                    window.api.set_pkg_info_row("{panel}", "description", "<span class='select'>{description}</span>");
                    window.api.set_pkg_info_row("{panel}", "author", "<span class='select'>{author}</span>");
                    window.api.set_pkg_info_row("{panel}", "repository", "<span class='select'>{repo}</span>");
                    window.api.set_pkg_info_row("{panel}", "location", "<span class='select'>{location}</span>");
                    window.api.set_pkg_info_row("{panel}", "version", "<span class='select'>{version}</span>");
                    window.api.set_pkg_info_row("{panel}", "license", "<span class='select'>{license}</span>");
                """);

        # proc loaded(s: string) = jsLog(s)
        proc filter(s: string) = filter_pkgs(s)
        proc packages(s: string) = asyncCheck get_packages(s)
        proc packages_outd(s: string) = asyncCheck get_packages_outd(s)
        proc packages_avai(s: string) = asyncCheck get_packages_avai(s)
        proc config() = get_config()
        proc clear_cache() = asyncCheck settings_clear_cache()

        proc update_state(state: int) = setting_config_state(state)
        proc update_cache(state: int) = setting_config_cache(state)
        proc update_debug(state: int) = setting_config_debug(state)
        proc update_singletons(state: int) = setting_config_singletons(state)
        proc reset_settings() = settings_reset()
        proc doctor() = asyncCheck checkup()
        proc update() = asyncCheck updater()
        proc rpkgs(s: string) = asyncCheck rempkgs(s)
        proc epkgs(s: string) = asyncCheck enapkgs(s)
        proc dpkgs(s: string) = asyncCheck dispkgs(s)
        # proc ready() = app.js("main();")

    # Once Webview has loaded, run callback to start splash animation.
    `externalInvokeCB=`(app, proc (w: Webview; arg: string) = w.js("main();"))
    # [https://github.com/juancarlospaco/borapp/blob/master/src/borapp.nim#L52]
    # app.run(
    #     (
    #         proc () {.noconv.} = # Normal close.
    #             # Do something...
    #     ),
    #     (
    #         proc () {.noconv.} = # CTRL+C close.
    #             # Do something...
    #     )
    # )
    app.run()
    app.exit()

# [https://nim-lang.org/docs/asyncnet.html#examples-chat-server]
# waitFor main()
main()
