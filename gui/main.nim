import os, algorithm, browsers, webgui, parsecfg, strformat, osproc, asyncdispatch, re
from times import format, getTime, toUnix
import strutils except escape
from xmltree import escape
import uri
import json
import httpclient
import tables
import streams

proc main() =

    # [https://forum.nim-lang.org/t/6474#39947]
    type
        ChannelMsg = ref object of RootObj
            action, rpath: string
            future: ptr Future[Response]

            inst_all: bool
            inst_a_names: ptr seq[string]

            avai_pname: string
            avai_db: ptr Table[string, JsonNode]

            updater_cmd: string

        Response = ref object of RootObj
            inst_err: string
            inst_pkgs: ptr seq[Package]
            inst_a_names: ptr seq[string]

            avai_pname: string
            avai_names: ptr seq[string]
            avai_jdata: ptr seq[JsonNode]
            avai_db: ptr Table[string, JsonNode]

            outd_pkgs: ptr seq[Outdated]

            checkup: ptr tuple[status, version, binary: string]

            update_code: int

        Package = tuple[name, version: string, disabled: bool]

        Outdated = tuple[
            name,
            local_version,
            remote_version: string,
            config: OrderedTableRef[string, OrderedTableRef[string, string]]
        ]

    var INST_PKGS: seq[Package] = @[]
    var AVAI_PKGS_NAMES: seq[string] = @[]
    var AVAI_PKGS = initTable[string, JsonNode]()
    var OUTD_PKGS: seq[Outdated]
    var FIRST_RUNS = {"INST": false, "AVAI": false, "OUTD": false}.toTable

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
        const width = 1100  # + 1100
        const height = 660 # + 750
        const minWidth = width
        const minHeight = height
    elif defined(macosx):
        const width = 700
        const height = 450
        const minWidth = 650
        const minHeight = 400

    let hdir = os.getEnv("HOME")
    let registrypath = joinPath(hdir, "/.nodecliac/registry")
    # var app {.threadvar.}: Webview
    let app = newWebView(currentHtmlPath("views/index.html"),
        debug=true,
        title="nodecliac GUI",
        width=width, height=height,
        minWidth=minWidth, minHeight=minHeight,
        resizable=true,
        cssPath=currentHtmlPath("css/empty.css") # [Bug] Line doesn't work on macOS?
    )

# ==============================================================================

    proc collapse_html(html: string): string =
        return html.strip().unindent().multiReplace([("\n", "")])
        # return html.strip().multiReplace([(re("^ \\s*", {reMultiLine}), ""), (re("\n"), "")])

    proc clink(url: string): string =
        return fmt"""
            <a class=\"link\"
                target=\"_blank\"
                onclick=\"api.open(this.href)\"
                href=\"{url}\">
                {url}
            </a>""".collapse_html()

    proc flink(url: string): string =
        return fmt"""
            <a class=\"link\"
                onclick=\"api.fopen(this.textContent)\">
                {url}
            </a>""".collapse_html()

     # [https://stackoverflow.com/a/6712058]
    proc palphasort(a, b: Package): int =
        let aname = a.name.toLower()
        let bname = b.name.toLower()
        if aname < bname: result = -1 # Sort string ascending.
        elif aname > bname: result = 1
        else: result = 0 # Default return value (no sorting).

    # [https://stackoverflow.com/a/6712058]
    # Nim Json sorting: [https://forum.nim-lang.org/t/6332#39027]
    proc jalphasort(a, b: JsonNode): int =
        let aname = a{"name"}.getStr().toLower()
        let bname = b{"name"}.getStr().toLower()
        if aname < bname: result = -1 # Sort string ascending.
        elif aname > bname: result = 1
        else: result = 0 # Default return value (no sorting).

# ==============================================================================

    const templates = {
        "inst": """
        <div class=entry id=pkg-entry-$1>
            <div class="center">
                <div class="checkmark" data-name="$1">
                    <i class="fas fa-check none"></i>
                </div>
                <div class="pstatus $2"></div>
                <div class="label">$1</div>
            </div>
        </div>""".collapse_html(),
        "avai": """
        <div class=entry id=pkg-entry-$1>
            <div class="center">
                <div class="checkmark" data-name="$1">
                    <i class="fas fa-check none"></i>
                </div>
                <div class="pstatus $2"></div>
                <div class="label">$1</div>
                <div class="loader-cont none">
                    <div class="svg-loader s-loader"></div>
                </div>
                <div class="istatus none"></div>
            </div>
        </div>""".collapse_html(),
        "outd": """
        <div class=entry id=pkg-entry-$1>
            <div class="center">
                <div class="checkmark" data-name="$1">
                    <i class="fas fa-check none"></i>
                </div>
                <div class="label">$1</div>
            </div>
        </div>""".collapse_html(),
        "update": """
        <div class="logitem row new-highlight $1">
            <div class="logitem-top">
                <div class="left center">
                    <div class="icon">
                        <i class="$2"></i>
                    </div>
                    <div class="title">$3</div>
                </div>
                <div class="right">
                    <div class="time">
                        $4
                    </div>
                </div>
            </div>
            <div>$5</div>
        </div>""".collapse_html(),
        "doctor": """
        <div class="header none">Log</div>
        <div class="row">
            <div class="label">nodecliac ping:</div>
            $1
        </div>
        <div class="row">
            <div class="label">nodecliac -v:</div>
            <div class="value">v$2</div>
        </div>
        <div class="row">
            <div class="label">bin:</div>
            <div class="value">$3</div>
        </div>""".collapse_html()
    }.toTable

# ==============================================================================

    proc t_get_packages_inst(chan: ptr Channel[ChannelMsg]) {.thread.} =
        while true: # [https://git.io/JtHvI]
            var incoming = chan[].recv()
            if not incoming.future[].finished:
                var response = Response(update_code: -1)

                let r = re"@disable\s=\strue"
                var packages: seq[Package] = @[]
                let registrypath = incoming.rpath
                const dirtypes = {pcDir, pcLinkToDir}
                for kind, path in walkDir(registrypath):
                    if kind notin dirtypes: continue

                    let (path, command) = splitPath(path)
                    var version = "0.0.1"
                    var disabled = false

                    let config = joinPath(path, "package.ini")
                    if fileExists(config):
                        version = loadConfig(config).getSectionValue("Package", "version")

                    let dconfig = joinPath(path, command, fmt".{command}.config.acdef")
                    if fileExists(dconfig):
                        if find(readFile(dconfig), r) > -1: disabled = true

                    var pkg: Package = (command, move(version), disabled)
                    packages.add(move(pkg))

                packages.sort(palphasort)
                response.inst_pkgs = addr packages

                incoming.future[].complete(response)

    proc get_packages_inst(s: string) {.async.} =
        let jdata = parseJSON(s)
        let input = jdata["input"].getStr()
        let panel = jdata["panel"].getStr()
        let force = jdata{"force"}.getBool()

        if FIRST_RUNS["INST"] and not force: return
        FIRST_RUNS["INST"] = true

        app.js(fmt"""get_panel_by_name("{panel}").$sbentry.classList.remove("none");""")

        var chan: Channel[ChannelMsg]
        chan.open()
        var thread: Thread[ptr Channel[ChannelMsg]]
        createThread(thread, t_get_packages_inst, addr chan)

        var fut = newFuture[Response]("get-packages-inst.nodecliac")
        let data = ChannelMsg(future: addr fut, rpath: registrypath)
        chan.send(data)
        let r = await fut
        INST_PKGS = r.inst_pkgs[]
        chan.close()

        var html = ""
        if INST_PKGS.len == 0:
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
            for item in INST_PKGS:
                if input != "":
                    if input notin item.name: continue
                let classname = if item.disabled: "off" else: "on"
                html &= templates["inst"] % [item.name, classname]

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
                app.js(fmt"""get_panel_by_name("{panel}").$sbentry.classList.add("none");""")
        )

# ------------------------------------------------------------------------------

    proc filter_inst_pkgs(input: string) =
        # Remove nodes: [https://stackoverflow.com/a/3955238]
        # Fragment: [https://howchoo.com/code/learn-the-slow-and-fast-way-to-append-elements-to-the-dom]
        # Fuzzy search:
        # [https://github.com/nim-lang/Nim/issues/13955]
        # [https://github.com/nim-lang/Nim/blob/devel/tools/dochack/dochack.nim]
        # [https://github.com/nim-lang/Nim/blob/devel/tools/dochack/fuzzysearch.nim]
        # [https://www.forrestthewoods.com/blog/reverse_engineering_sublime_texts_fuzzy_match/]

        var html = ""
        var empty = true
        var command = fmt"""
            var PANEL = get_panel_by_name("packages-installed");
            PANEL.jdata_filtered.length = 0;
            """

        for item in INST_PKGS:
            if input in item.name:
                empty = false
                # let name_escaped = item.name.escape
                let classname = if item.disabled: "off" else: "on"

                command &= fmt"""PANEL.jdata_filtered.push("{item.name}");"""
                html &= templates["inst"] % [item.name, classname]

        if empty: html &= """<div class="empty"><div>No Packages</div></div>"""
        command &= fmt"""
            PANEL.$entries.textContent = "";
            PANEL.$entries.insertAdjacentHTML("afterbegin", `{html}`);
            PKG_PANES_REFS.$input_loader.classList.add("none");
        """

        app.js(command)

# ------------------------------------------------------------------------------

    proc t_inst_actions(chan: ptr Channel[ChannelMsg]) {.thread.} =
        while true: # [https://git.io/JtHvI]
            var incoming = chan[].recv()
            if not incoming.future[].finished:
                var response = Response()

                let all = incoming.inst_all
                let action = incoming.action
                let registrypath = incoming.rpath
                var names = (
                    if not all: incoming.inst_a_names[]
                    else:
                        var names: seq[string] = @[]
                        const dirtypes = {pcDir, pcLinkToDir}
                        for kind, path in walkDir(registrypath):
                            if kind notin dirtypes: continue
                            let parts = splitPath(path)
                            names.add(parts.tail)
                        names.sort()
                        names
                )

                case action:
                    of "disable", "enable":
                        var cmd = "nodecliac " & action
                        for name in names: cmd &= " " & name
                        discard execProcess(cmd)
                    of "remove":
                        for name in names:
                            let p = joinPath(registrypath, name)
                            if dirExists(p): removeDir(p)
                    else: discard

                incoming.future[].complete(response)

    proc enapkgs(s: string) {.async.} =
        let jdata = parseJSON(s)
        let all = jdata["all"].getBool()
        let panel = jdata["panel"].getStr()

        app.js(fmt"""get_panel_by_name("{panel}").$tb_loader.classList.remove("none");""")

        var names: seq[string] = @[]
        for item in items(jdata["names"]):
            let name = item.getStr()
            if name != "nodecliac": names.add(name)

        var chan: Channel[ChannelMsg]
        chan.open()
        var thread: Thread[ptr Channel[ChannelMsg]]
        createThread(thread, t_inst_actions, addr chan)

        var fut = newFuture[Response]("enapkgs.nodecliac")
        let data = ChannelMsg(
            future: addr fut,
            action: "enable",
            rpath: registrypath,
            inst_a_names: addr names,
            inst_all: all
        )
        chan.send(data)
        discard await fut
        chan.close()

        var command = ""
        for name in names:
            command &= fmt"""var $status = f("#pkg-entry-{name}").all().classes("pstatus").getElement();
                var classes = $status.classList;
                classes.remove("off");
                classes.add("on");
                """

        if all:
            command = fmt"""
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
                {command}
                get_panel_by_name("{panel}").$tb_loader.classList.add("none");
                """)
        )

    proc dispkgs(s: string) {.async.} =
        let jdata = parseJSON(s)
        let all = jdata["all"].getBool()
        let panel = jdata["panel"].getStr()

        app.js(fmt"""get_panel_by_name("{panel}").$tb_loader.classList.remove("none");""")

        var names: seq[string] = @[]
        for item in items(jdata["names"]):
            let name = item.getStr()
            if name != "nodecliac": names.add(name)

        var chan: Channel[ChannelMsg]
        chan.open()
        var thread: Thread[ptr Channel[ChannelMsg]]
        createThread(thread, t_inst_actions, addr chan)

        var fut = newFuture[Response]("dispkgs.nodecliac")
        let data = ChannelMsg(
            future: addr fut,
            action: "disable",
            rpath: registrypath,
            inst_a_names: addr names,
            inst_all: all
        )
        chan.send(data)
        discard await fut
        chan.close()

        var command = ""
        for name in names:
            command &= fmt"""var $status = f("#pkg-entry-{name}").all().classes("pstatus").getElement();
                var classes = $status.classList;
                classes.remove("on");
                classes.add("off");
                """

        if all:
            command = fmt"""
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
                {command}
                get_panel_by_name("{panel}").$tb_loader.classList.add("none");
                """)
        )

    proc rempkgs(s: string) {.async.} =
        let jdata = parseJSON(s)
        let all = jdata["all"].getBool()
        let panel = jdata["panel"].getStr()

        app.js(fmt"""get_panel_by_name("{panel}").$tb_loader.classList.remove("none");""")

        var names: seq[string] = @[]
        for item in items(jdata["names"]):
            let name = item.getStr()
            if name != "nodecliac": names.add(name)

        var chan: Channel[ChannelMsg]
        chan.open()
        var thread: Thread[ptr Channel[ChannelMsg]]
        createThread(thread, t_inst_actions, addr chan)

        var fut = newFuture[Response]("rempkgs.nodecliac")
        let data = ChannelMsg(
            future: addr fut,
            action: "remove",
            rpath: registrypath,
            inst_a_names: addr names,
            inst_all: all
        )
        chan.send(data)
        discard await fut
        chan.close()

        var command = ""
        for name in names:
            command &= fmt"""
                var $child = document.getElementById("pkg-entry-{name}");
                $child.parentElement.removeChild($child);
                """
        if all: command &= fmt"""get_panel_by_name("{panel}").$entries.innerHTML = "";"""

        app.dispatch(
            proc () =
                app.js(fmt"""
                {command}
                get_panel_by_name("{panel}").$tb_loader.classList.add("none");
                """)
        )

# ==============================================================================

    proc t_get_packages_avai(chan: ptr Channel[ChannelMsg]) {.thread.} =
        while true: # [https://git.io/JtHvI]
            var incoming = chan[].recv()
            if not incoming.future[].finished:
                var response = Response()
                var avai_db = incoming.avai_db[]
                var avai_names: seq[string] = @[]
                let cached_avai = joinPath(os.getEnv("HOME"), "/.nodecliac/.cached_avai")
                let url = "https://raw.githubusercontent.com/cgabriel5/nodecliac-packages/master/packages.json"

                proc fetchjson(url: string): Future[string] {.async.} =
                    let client = newAsyncHttpClient()
                    let contents = await client.getContent(url)
                    return contents

                proc getpkgs() {.async.} =
                    let cache_exists = fileExists(cached_avai)
                    let cache_fresh = (
                        if cache_exists:
                            let mtime = getLastModificationTime(cached_avai).toUnix()
                            let ctime = getTime().toUnix()
                            not (ctime - mtime > 60)
                        else: true
                    )
                    let usecache = cache_exists and cache_fresh

                    let contents = if usecache: readFile(cached_avai) else: await fetchjson(url)
                    var jdata = parseJSON(contents).getElems.sorted(jalphasort)

                    for item in items(jdata):
                        let name = item["name"].getStr()
                        avai_db[name] = item
                        avai_names.add(name)

                    if not usecache:
                        var sjson = $jdata
                        if sjson != "": sjson.delete(0, 0)
                        writeFile(cached_avai, sjson)

                    response.avai_db = addr avai_db
                    response.avai_jdata = addr jdata
                    response.avai_names = addr avai_names

                    incoming.future[].complete(response)

                waitFor getpkgs()

    proc get_packages_avai(s: string) {.async.} =
        let jdata = parseJSON(s)
        let input = jdata["input"].getStr()
        let panel = jdata["panel"].getStr()
        let force = jdata{"force"}.getBool()

        if FIRST_RUNS["AVAI"] and not force: return
        FIRST_RUNS["AVAI"] = true

        app.js(fmt"""get_panel_by_name("{panel}").$sbentry.classList.remove("none");""")

        var chan: Channel[ChannelMsg]
        chan.open()
        var thread: Thread[ptr Channel[ChannelMsg]]
        createThread(thread, t_get_packages_avai, addr chan)

        var fut = newFuture[Response]("get-packages-avai.nodecliac")
        let data = ChannelMsg(future: addr fut, avai_db: addr AVAI_PKGS)
        chan.send(data)
        let r = await fut
        chan.close()

        var objects = r.avai_jdata[]
        AVAI_PKGS = r.avai_db[]
        AVAI_PKGS_NAMES = r.avai_names[]

        var html = ""
        if objects.len == 0:
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
            var add_names = ""
            for obj in objects:
                let name = obj{"name"}.getStr()

                add_names &= fmt"""PANEL.jdata_names.push("{name}");"""

                if input != "":
                    if input notin name: continue
                let p = joinPath(registrypath, name)
                let classname = if dirExists(p): "on" else: "clear"
                html &= templates["avai"] % [name, classname]

            app.dispatch(
                proc () =
                    app.js(
                        fmt"""
                        var PANEL = get_panel_by_name("{panel}");
                        PANEL.$entries.textContent = "";
                        PANEL.$entries.insertAdjacentHTML("afterbegin", `{html}`);
                        {add_names}
                        """
                    )
            )

        app.dispatch(
            proc () =
                app.js(fmt"""
                    var PANEL = get_panel_by_name("{panel}");
                    PANEL.$sbentry.classList.add("none");
                    toggle_pkg_sel_action_refresh(true);
                """)
        )

# ------------------------------------------------------------------------------

    proc filter_avai_pkgs(input: string) =
        # Remove nodes: [https://stackoverflow.com/a/3955238]
        # Fragment: [https://howchoo.com/code/learn-the-slow-and-fast-way-to-append-elements-to-the-dom]
        # Fuzzy search:
        # [https://github.com/nim-lang/Nim/issues/13955]
        # [https://github.com/nim-lang/Nim/blob/devel/tools/dochack/dochack.nim]
        # [https://github.com/nim-lang/Nim/blob/devel/tools/dochack/fuzzysearch.nim]
        # [https://www.forrestthewoods.com/blog/reverse_engineering_sublime_texts_fuzzy_match/]

        var html = ""
        var empty = true
        var command = fmt"""
            var PANEL = get_panel_by_name("packages-available");
            PANEL.jdata_filtered.length = 0;
            """

        for name in AVAI_PKGS_NAMES:
            if input in name:
                empty = false
                let p = joinPath(registrypath, name)
                let classname = if dirExists(p): "on" else: "clear"

                command &= fmt"""PANEL.jdata_filtered.push("{name}");"""
                html &= templates["avai"] % [name, classname]

        if empty: html &= """<div class="empty"><div>No Packages</div></div>"""
        command &= fmt"""
            PANEL.$entries.textContent = "";
            PANEL.$entries.insertAdjacentHTML("afterbegin", `{html}`);
            PKG_PANES_REFS.$input_loader.classList.add("none");
        """

        app.js(command)

# ------------------------------------------------------------------------------

    proc t_installpkg(chan: ptr Channel[ChannelMsg]) {.thread.} =
        while true: # [https://git.io/JtHvI]
            var incoming = chan[].recv()
            if not incoming.future[].finished:
                var response = Response()

                let name = incoming.avai_pname
                let avai_db = incoming.avai_db[]

                if avai_db.hasKey(name):
                    let scheme = avai_db[name]{"scheme"}.getStr()
                    let cmd = fmt"""nodecliac add --repo "{scheme}" --skip-val;"""
                    let res = execProcess(cmd).strip(trailing=true)
                    if "exists" in res: response.inst_err = $res

                incoming.future[].complete(response)

    var install_queue: seq[string] = @[]
    proc installpkg(s: string, stop: bool = false) {.async.} =
        var jdata = parseJSON(s)
        let name = jdata["name"].getStr()
        let panel = jdata["panel"].getStr()

        # Queue logic.
        if not stop: install_queue.add(name)
        if install_queue.len > 1 and not stop: return

        app.js(
            fmt"""
            var PANEL = get_panel_by_name("{panel}");
            PANEL.$tb_loader.classList.remove("none");
            f(PANEL.$tb).all().classes("tb-action-first").getElement().classList.add("disabled");
            """
        )

        var chan: Channel[ChannelMsg]
        chan.open()
        var thread: Thread[ptr Channel[ChannelMsg]]
        createThread(thread, t_installpkg, addr chan)

        var fut = newFuture[Response]("installpkgs.nodecliac")
        let data = ChannelMsg(future: addr fut, avai_db: addr AVAI_PKGS, avai_pname: name)
        chan.send(data)
        let r = await fut
        chan.close()
        let err = r.inst_err

        var cmd = fmt"""
            var PANEL = get_panel_by_name("{panel}");
            var $status = f("#pkg-entry-{name}").all().classes("pstatus").getElement();
            var classes = $status.classList;
            classes.remove("clear");
            classes.add("on");"""

        if err != "":
            cmd &= fmt"""var $status = f("#pkg-entry-{name}").all().classes("istatus").getElement();
            var classes = $status.classList;
            classes.remove("none");
            classes.add("on");
            $status.innerText = "Err: {err}";
            """

        app.dispatch(
            proc () =
                if install_queue.len <= 1:
                    cmd &= fmt"""get_panel_by_name("{panel}").$tb_loader.classList.add("none");"""

                app.js(
                    fmt"""
                    {cmd}
                    f(PANEL.$tb).all().classes("tb-action-first").getElement().classList.remove("disabled");
                    """
                )

                # Finally, remove name from queue and continue queue.
                install_queue.delete(0)
                if install_queue.len != 0:
                    jdata["name"] = %* install_queue[0]
                    asyncCheck installpkg($jdata, true)
        )

# ==============================================================================

    proc t_get_packages_outd(chan: ptr Channel[ChannelMsg]) {.thread.} =
        while true: # [https://git.io/JtHvI]
            var incoming = chan[].recv()
            if not incoming.future[].finished:
                var response = Response()

                # let r = re"@disable\s=\strue"
                let registrypath = incoming.rpath
                var urls = initTable[string, string]()
                var packages: seq[Package] = @[]
                var urltemp = "https://raw.githubusercontent.com/$1/$2/master"
                const dirtypes = {pcDir, pcLinkToDir}
                for kind, path in walkDir(registrypath):
                    if kind notin dirtypes: continue

                    let command #[(head, command)]# = splitPath(path).tail
                    var version = "0.0.1"
                    var disabled = false
                    var url = ""

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
                            var path = parseUri(repo).path
                            path.removePrefix({'/'})
                            let (username, reponame) = splitPath(move(path))
                            # [https://stackoverflow.com/a/58742269]
                            # [https://stackoverflow.com/a/42484886]
                            url = urltemp % [username, reponame]
                            if sub != "": url &= fmt"/{sub}"
                            url &= "/package.ini"
                            # url &= fmt"/{command}.acmap"

                    urls[command] = move(url)

                    # let dconfig = joinPath(path, command, fmt".{command}.config.acdef")
                    # if fileExists(dconfig):
                    #     if find(readFile(dconfig), r) > -1: disabled = true

                    var pkg: Package = (command, move(version), disabled)
                    packages.add(move(pkg))

                packages.sort(palphasort)

                # ------------------------------------------------------

                var outdated: seq[Outdated] = @[]

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

                proc testhttp {.async.} =
                    var reqs: seq[Future[string]]
                    for item in packages:
                        reqs.add(fetchfile(urls[item.name]))
                    let reponses = await all(reqs)
                    for i, response in reponses:
                        let data = loadConfig(newStringStream(response))
                        let remote_version = data.getSectionValue("Package", "version")
                        let local_version = packages[i].version;

                        if  local_version != remote_version:
                            var item: Outdated = (
                                name: packages[i].name,
                                local_version: local_version,
                                remote_version: remote_version,
                                config: data
                            )
                            outdated.add(item)

                    response.outd_pkgs = addr outdated
                    incoming.future[].complete(response)

                waitFor testhttp()

    proc get_packages_outd(j: string) {.async.} =
        let jdata = parseJSON(j)
        let s = jdata["input"].getStr()
        let panel = jdata["panel"].getStr()
        let force = jdata{"force"}.getBool()

        if FIRST_RUNS["OUTD"] and not force: return
        FIRST_RUNS["OUTD"] = true

        app.js(fmt"""
            var PANEL = get_panel_by_name("{panel}");
            PANEL.$sbentry.classList.remove("none");
        """)

        var chan: Channel[ChannelMsg]
        chan.open()
        var thread: Thread[ptr Channel[ChannelMsg]]
        createThread(thread, t_get_packages_outd, addr chan)

        var fut = newFuture[Response]("get-packages-out.nodecliac")
        let data = ChannelMsg(future: addr fut, rpath: registrypath)
        chan.send(data)
        let r = await fut
        OUTD_PKGS = r.outd_pkgs[]
        chan.close()

        var html = ""
        if OUTD_PKGS.len == 0:
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
            for item in OUTD_PKGS:
                if s != "":
                    if s notin item.name: continue
                html &= templates["outd"] % [item.name]

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
                """)
        )

# ==============================================================================

    let configpath = joinPath(hdir, "/.nodecliac/.config")
    proc config_update(setting: string, value: int) =
        var config = if fileExists(configpath): readFile(configpath) else: ""
        let index = (case setting
            of "status": 0
            of "cache": 1
            of "debug": 2
            else: 3
        )

        if config != "":
            config[index] = ($(value))[0]
            writeFile(configpath, config)

    proc setting_config_state(state: int) = config_update("status", state)
    proc setting_config_cache(state: int) = config_update("cache", state)
    proc setting_config_debug(state: int) = config_update("debug", state)
    proc setting_config_singletons(state: int) = config_update("singletons", state)

    proc settings_reset() =
        const value = "1001"
        writeFile(configpath, value)
        # [https://stackoverflow.com/a/62563753]
        app.js("window.api.setup_config(" & cast[seq[char]](value).join(",") & ");")

# ------------------------------------------------------------------------------

    proc get_config() =
        let config = if fileExists(configpath): readFile(configpath) else: ""
        if config != "":
            let status = config[0]
            let cache = config[1]
            let debug = config[2]
            let singletons = config[3]
            app.js(fmt"window.api.setup_config({status},{cache},{debug},{singletons});")

# ==============================================================================

    proc t_cache(chan: ptr Channel[ChannelMsg]) {.thread.} =
        while true: # [https://git.io/JtHvI]
            var incoming = chan[].recv()
            if not incoming.future[].finished:
                var response = Response()

                # Use nodecliac CLI.
                # discard execProcess("nodecliac cache --clear")

                # Nim native `nodecliac cache --clear` equivalent...
                let cp = joinPath(os.getEnv("HOME"), "/.nodecliac/.cache")
                if dirExists(cp):
                    for kind, path in walkDir(cp):
                        if kind == pcFile: discard tryRemoveFile(path)

                incoming.future[].complete(response)

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
        createThread(thread, t_cache, addr chan)

        var fut = newFuture[Response]("clear-cache.nodecliac")
        let data = ChannelMsg(future: addr fut)
        chan.send(data)
        discard await fut
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

# ==============================================================================

    proc t_update(chan: ptr Channel[ChannelMsg]) {.thread.} =
        while true: # [https://git.io/JtHvI]
            var incoming = chan[].recv()
            if not incoming.future[].finished:
                var response = Response(update_code: -1)

                # [https://stackoverflow.com/a/23931327]
                let uname = execProcess("id -u -n").strip(trailing=true)

                # Ask user for password.
                let input = dialogInput(
                    aTitle = "Authentication Required",
                    aMessage = fmt"Authentication required to update nodecliac, please enter your password.\n\nPassword for {uname}:",
                    aDefaultInput = nil,
                    aIconType = "info"
                )

                # Validate user password: [https://askubuntu.com/a/622419]
                if input.len != 0:
                    let script = fmt"""#! /bin/bash
                        sudo -k
                        if sudo -lS &> /dev/null << EOF
                        {input}
                        EOF
                        then
                        {incoming.updater_cmd}
                        else
                        exit 1
                        fi
                    """
                    let cmd = fmt"""bash -c '{script}'"""
                    let code #[(res, code)]# = execCmdEx(cmd).exitCode
                    response.update_code = code

                incoming.future[].complete(response)

    proc updater() {.async.} =

        app.js("""
            document.getElementById("update-spinner").classList.remove("none");
            document.getElementById("update-update").classList.add("nointer", "disabled");
            """)

        let filename = currentSourcePath()
        let cwd = parentDir(filename)
        let script = joinPath(cwd, "updater.sh")

        var chan: Channel[ChannelMsg]
        chan.open()
        var thread: Thread[ptr Channel[ChannelMsg]]
        createThread(thread, t_update, addr chan)

        var fut = newFuture[Response]("update.nodecliac")
        let data = ChannelMsg(
            future: addr fut,
            updater_cmd: script,
            action: "update"
        )
        chan.send(data)
        let r = await fut
        let code = r.update_code
        chan.close()

        # [https://nim-lang.org/docs/times.html#parsing-and-formatting-dates]
        let datestring = getTime().format("MMM'.' d, yyyy (h:mm tt)")
        var title, message, icon, class: string
        case code
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

        let logentry = templates["update"] % [class, icon, title, datestring, message]

        app.dispatch(
            proc () =
                app.js(fmt"""
                    document.getElementById('update-output').insertAdjacentHTML('afterbegin', `{logentry}`);
                    document.getElementById("update-update").classList.remove("nointer", "disabled");
                    document.getElementById("update-spinner").classList.add("none");
                    """)
        )

# ==============================================================================

    proc t_doctor(chan: ptr Channel[ChannelMsg]) {.thread.} =
        while true: # [https://git.io/JtHvI]
            var incoming = chan[].recv()
            if not incoming.future[].finished:
                var response = Response()

                let status = execProcess("nodecliac").strip(trailing=true)
                let version = execProcess("nodecliac --version").strip(trailing=true)
                let binary = execProcess("command -v nodecliac").strip(trailing=true)

                var checkup: tuple[status, version, binary: string]
                checkup = (status, version, binary)

                response.checkup = addr checkup

                incoming.future[].complete(response)

    proc checkup() {.async.} =

        app.js("""
            document.getElementById("doctor-spinner").classList.remove("none");
            document.getElementById("doctor-run").classList.add("nointer", "disabled");
            """)

        var chan: Channel[ChannelMsg]
        chan.open()
        var thread: Thread[ptr Channel[ChannelMsg]]
        createThread(thread, t_doctor, addr chan)

        var fut = newFuture[Response]("doctor.nodecliac")
        let data = ChannelMsg(future: addr fut, action: "doctor")
        chan.send(data)
        let r = await fut
        let (status, version, binary) = r.checkup[]
        chan.close()

        let binloc =
            if binary.startsWith(hdir): binary.replace(hdir, "~")
            else: binary
        let ping =
            if status.len == 0: "<div class=\"value\">OK</div>"
            else: "<div class=\"value error\">ERROR</div>"

        let html = templates["doctor"] % [ping, version, binloc]

        app.dispatch(
            proc () =
                app.js(fmt"""
                document.getElementById("doctor-output").innerHTML = `{html}`;
                document.getElementById("doctor-run").classList.remove("nointer", "disabled");
                document.getElementById("doctor-spinner").classList.add("none");
                """)
        )

# ==============================================================================

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
            var cpath = path.strip(trailing=true)
            let rpath = joinPath(registrypath, splitPath(path).tail)
            if cpath.startsWith('~'):
                cpath.removePrefix('~')
                cpath = hdir & cpath
            when defined(linux):
                const explorer = "xdg-open" # [https://superuser.com/a/465542]
            elif defined(macosx):
                const explorer = "open"
            # Ensure path matches registry path before running command.
            if cpath == rpath and dirExists(rpath): discard execCmd(explorer & " " & rpath)

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
            let panel = jdata["panel"].getStr("")
            let exclude = jdata{"exclude"}.getStr("").split(',')

            # Check that package ini file exists.
            let config = joinPath(registrypath, name, "/package.ini")
            if fileExists(config):
                # Read the config file and get the needed data points.
                # [https://github.com/coffeepots/niminifiles]
                # [https://www.reddit.com/r/nim/comments/8gszys/nim_day_5_writing_ini_parser/]
                # [https://github.com/xmonader/nim-configparser]
                # [https://nim-lang.org/docs/parsecfg.html]
                let data = loadConfig(config)

                var jstr = ""
                const fields = ["name", "description", "author", "repository", "location", "version", "license"]
                for field in fields:
                    if field notin exclude:
                        var dt = ""
                        case field:
                        of "name": dt = data.getSectionValue("Package", "name".escape)
                        of "version": dt = data.getSectionValue("Package", "version".escape)
                        of "description": dt = data.getSectionValue("Package", "description".escape)
                        of "license": dt = data.getSectionValue("Package", "license".escape)
                        of "author": dt = data.getSectionValue("Author", "name".escape)
                        of "repository": dt = clink(data.getSectionValue("Author", "repo").escape)
                        of "location": dt = flink("~/.nodecliac/registry/" & name)
                        else: discard
                        jstr &= fmt"""window.api.set_pkg_info_row("{panel}", "{field}", "<span class='select'>{dt}</span>");"""
                app.js(fmt"""{jstr}""");

        # proc loaded(s: string) = jsLog(s)
        proc filter_inst(s: string) = filter_inst_pkgs(s)
        proc filter_avai(s: string) = filter_avai_pkgs(s)
        proc packages_ints(s: string) = asyncCheck get_packages_inst(s)
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
        proc ipkg(s: string) = asyncCheck installpkg(s)
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
