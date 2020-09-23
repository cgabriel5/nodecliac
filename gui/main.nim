import os, algorithm, browsers, strutils, webgui, parsecfg, strformat, osproc

when defined(linux):
    const width = 2000
    const height = 800
    const minWidth = 1000
    const minHeight = 600
elif defined(macosx):
    const width = 725
    const height = 500
    const minWidth = 300
    const minHeight = 350

let hdir = os.getEnv("HOME")
let app = newWebView(currentHtmlPath("views/index.html"),
    debug=true,
    title="nodecliac GUI",
    width=width, height=height,
    minWidth=minWidth, minHeight=minHeight,
    resizable=true,
    cssPath=currentHtmlPath("css/empty.css") # [Bug] Line doesn't work on macOS?
)

proc get_config() =
    let p =  hdir & "/.nodecliac/.config"
    let config = if fileExists(p): readFile(p) else: ""
    # if config != "":
        # app.js("setup_config(" & config & ")")
    if config != "":
        app.js("window.api.setup_config(\"" & config & "\");")
        jsLog(config)

proc get_packages() =
    var html = ""
    var names: seq[string] = @[]

    for kind, path in walkDir(hdir & "/.nodecliac/registry"):
        let parts = splitPath(path)
        names.add(parts.tail)

    names.sort()
    for n in names:
        html &= "<div class=\"pkg-entry\" id=\"pkg-entry-" & n &  "\">"
        html &= "<div class=\"center\">"
        # html &= "<div class=\"pkg-entry-icon\"><i class=\"fas fa-check-square\"></i></div>"
        # if n == "nodecliac":
            # html &= "<div class=\"pkg-entry-icon\"><i class=\"fas fa-check-square\"></i></div>"
        # else:
        html &= "<div class=\"pkg-entry-icon\"><i class=\"fas fa-square\"></i></div>"
        # html &= "<div class=\"pkg-entry-icon\"><i class=\"fal fa-square\"></i></div>"
        html &= "<div class=\"pkg-entry-label\">" & n & "</div>"
        html &= "</div>"
        html &= "</div>"

    app.js(
        app.setText("#pkg-list-entries", "") & ";" &
        app.addHtml("#pkg-list-entries", html, position=afterbegin)
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
            # []
            let data = loadConfig(config)
            let name = data.getSectionValue("Package", "name")
            let version = data.getSectionValue("Package", "version")
            let description = data.getSectionValue("Package", "description")
            let license = data.getSectionValue("Package", "license")
            let author = data.getSectionValue("Author", "name")
            let github = data.getSectionValue("Author", "github")
            let location = "~/.nodecliac/registry/" & name

            echo "document.getElementById(\"pkg-info-row-name\").children[1].innerHTML = \"<span class=\"select\">" & name & "</span>\";"

            app.js(
                # app.setText("#pkg-info-row-name", name) & ";" &
                # app.setText("#pkg-info-row-description", description) & ";" &
                # app.setText("#pkg-info-row-author", author) & ";" &
                # app.setText("#pkg-info-row-repository", github) & ";" &
                # app.setText("#pkg-info-row-version", version)



                "document.getElementById(\"pkg-info-row-name\").children[1].innerHTML = \"<span class='select'>" & name & "</span>\";" &
                "document.getElementById(\"pkg-info-row-description\").children[1].innerHTML = \"<span class='select'>" & description & "</span>\";" &
                "document.getElementById(\"pkg-info-row-author\").children[1].innerHTML = \"<span class='select'>" & author & "</span>\";" &
                "document.getElementById(\"pkg-info-row-repository\").children[1].innerHTML = \"<span class='select'>" & clink(github) & "</span>\";" &
                "document.getElementById(\"pkg-info-row-location\").children[1].innerHTML = \"<span class='select'>" & flink(location) & "</span>\";" &
                "document.getElementById(\"pkg-info-row-version\").children[1].innerHTML = \"<span class='select'>" & version & "</span>\";" &
                "document.getElementById(\"pkg-info-row-license\").children[1].innerHTML = \"<span class='select'>" & license & "</span>\";"
            )
        else:
            app.js(
                "document.getElementById(\"pkg-info-row-name\").children[1].textContent = \"--\";" &
                "document.getElementById(\"pkg-info-row-description\").children[1].textContent = \"--\";" &
                "document.getElementById(\"pkg-info-row-author\").children[1].textContent = \"--\";" &
                "document.getElementById(\"pkg-info-row-repository\").children[1].textContent = \"--\";" &
                "document.getElementById(\"pkg-info-row-location\").children[1].textContent = \"--\";" &
                "document.getElementById(\"pkg-info-row-version\").children[1].textContent = \"--\";" &
                "document.getElementById(\"pkg-info-row-license\").children[1].textContent = \"--\";"
            )

    proc loaded(s: string) = jsLog(s)
    proc packages() = get_packages()
    proc config() = get_config()

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
