import os, algorithm, browsers, webgui, parsecfg, strformat, osproc
import strutils except escape
from xmltree import escape

when defined(linux):
    const width = 1100
    const height = 750
    const minWidth = 950
    const minHeight = 600
elif defined(macosx):
    const width = 700
    const height = 450
    const minWidth = 650
    const minHeight = 400

let hdir = os.getEnv("HOME")
let app = newWebView(currentHtmlPath("views/index.html"),
    debug=true,
    title="nodecliac GUI",
    width=width, height=height,
    minWidth=minWidth, minHeight=minHeight,
    resizable=true,
    cssPath=currentHtmlPath("css/empty.css") # [Bug] Line doesn't work on macOS?
)

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
    echo "RESET FILE"
    writeFile(hdir & "/.nodecliac/.config", "1001")
    app.js(fmt"window.api.setup_config(1,0,0,1);")

proc setting_config_state(state: int) =
    config_update("status", state)

proc setting_config_cache(state: int) =
    config_update("cache", state)

proc setting_config_debug(state: int) =
    config_update("debug", state)

proc setting_config_singletons(state: int) =
    config_update("singletons", state)

proc settings_clear_cache() =
    # Use nodecliac CLI
    # let res = execProcess("nodecliac cache --clear")

    app.js(
        "document.body.classList.add(\"nointer\");" &
        "document.getElementById(\"loader\").classList.remove(\"none\");" &
        "setTimeout(function() { document.getElementById(\"loader\").classList.add(\"opa1\"); }, 10);"
    )

    # Or write out Nim equivalent?
    let cp = hdir & "/.nodecliac/.cache"
    if dirExists(cp):
        for kind, path in walkDir(cp):
            if kind == pcFile: discard tryRemoveFile(path)

    app.js(
        "setTimeout(function() { document.getElementById(\"loader\").classList.add(\"opa1\"); setTimeout(function() { document.getElementById(\"loader\").classList.add(\"none\"); document.body.classList.remove(\"nointer\"); }, 10); }, 250);")

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
        jsLog(config)

var names: seq[string] = @[]
for kind, path in walkDir(hdir & "/.nodecliac/registry"):
    let parts = splitPath(path)
    names.add(parts.tail)
names.sort()

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
var $pkg_cont = document.getElementById("pkg-entries");
while ($pkg_cont.firstChild) $pkg_cont.removeChild($pkg_cont.lastChild);
var $fragment = document.createDocumentFragment();
"""

    var empty = true

    for name in names:
        if s in name:
            empty = false
            let name_escaped = name.escape
            command &= fmt"""
var $entry = document.createElement("div");
$entry.className = "entry";
$entry.id = "pkg-entry-{name_escaped}";

var $inner = document.createElement("div");
$inner.className = "center";

var $icon_cont = document.createElement("div");
$icon_cont.className = "icon-cont";
var $icon = document.createElement("i");
$icon.className = "fal fa-square checkmark";
$icon_cont.appendChild($icon);

var $label = document.createElement("div");
$label.className = "label";
$label.textContent = "{name_escaped}";

$inner.appendChild($icon_cont);
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
document.getElementById("search-spinner").classList.add("none");
"""

    app.js(command)

proc get_packages() =
    var html = ""
    var names: seq[string] = @[]

    var empty = true
    for kind, path in walkDir(hdir & "/.nodecliac/registry"):
        empty = false
        let parts = splitPath(path)
        names.add(parts.tail)

    if empty:
        let html = """<div class="empty"><div>No Packages</div></div>"""
        app.js(
            app.setText("#pkg-entries", "") & ";" &
            app.addHtml("#pkg-entries", html, position=afterbegin)
        )
    else:
        names.sort()
        for n in names:
            html &= "<div class=\"entry\" id=\"pkg-entry-" & n &  "\">"
            html &= "<div class=\"center\">"
            html &= "<div class=\"icon-cont\"><i class=\"fal fa-square checkmark\"></i></div>"
            html &= "<div class=\"label\">" & n & "</div>"
            html &= "</div>"
            html &= "</div>"

        app.js(
            app.setText("#pkg-entries", "") & ";" &
            app.addHtml("#pkg-entries", html, position=afterbegin)
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

    proc get_pkg_info(name: string) =
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
            let github = clink(data.getSectionValue("Author", "github").escape)
            let location = flink("~/.nodecliac/registry/" & name)

            app.js(fmt"""
                window.api.set_pkg_info_row("name", "<span class='select'>{name}</span>");
                window.api.set_pkg_info_row("description", "<span class='select'>{description}</span>");
                window.api.set_pkg_info_row("author", "<span class='select'>{author}</span>");
                window.api.set_pkg_info_row("repository", "<span class='select'>{github}</span>");
                window.api.set_pkg_info_row("location", "<span class='select'>{location}</span>");
                window.api.set_pkg_info_row("version", "<span class='select'>{version}</span>");
                window.api.set_pkg_info_row("license", "<span class='select'>{license}</span>");
            """);

    proc loaded(s: string) = jsLog(s)
    proc filter(s: string) = filter_pkgs(s)
    proc packages() = get_packages()
    proc config() = get_config()
    proc clear_cache() = settings_clear_cache()

    proc update_state(state: int) = setting_config_state(state)
    proc update_cache(state: int) = setting_config_cache(state)
    proc update_debug(state: int) = setting_config_debug(state)
    proc update_singletons(state: int) = setting_config_singletons(state)
    proc reset_settings() = settings_reset()

# import libfswatch
# import libfswatch/fswatch
# proc callback(event: fsw_cevent, event_num: cuint) =
#     echo event.path
# let hdir = os.getEnv("HOME")
# var mon = newMonitor()
# mon.addPath(hdir & "/.nodecliac/registry")
# mon.setCallback(callback)
# mon.start()

# get_packages()
app.run()
app.exit()
