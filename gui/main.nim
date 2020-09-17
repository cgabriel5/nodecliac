import os, algorithm, browsers, strutils, webgui

when defined(linux):
    const width = 1000
    const height = 800
    const minWidth = 600
    const minHeight = 600
elif defined(macosx):
    const width = 725
    const height = 500
    const minWidth = 300
    const minHeight = 350

let app = newWebView(currentHtmlPath("views/index.html"),
    debug=true, title="nodecliac GUI",
    width=width, height=height,
    minWidth=minWidth, minHeight=minHeight,
    resizable=true,
    cssPath=currentHtmlPath("css/empty.css") # [Bug] Line doesn't work on macOS?
)

template addHtmlS(_: Webview; id, html: string, position = beforeEnd): string =
  ## Appends **HTML** to an Element by `id` at `position`, uses `insertAdjacentHTML()`, JavaScript side.
  ## * https://developer.mozilla.org/en-US/docs/Web/API/Element/insertAdjacentHtml
  assert id.len > 0, "ID must not be empty string, must have an ID"
  "document.querySelector(" & id & ").insertAdjacentHTML('" & $position & "',`" & html.replace('`', ' ') & "`);"

proc innerHTML(_: Webview; id: string, html=""): string =
  "document.getElementById('" & id & "').innerHTML = \"\";"

template clearHTML(id: string) =
  app.js(innerHTML(app, id, ""))

proc getPackages() =
    let hdir = os.getEnv("HOME")
    var names: seq[string] = @[]

    var html = """
<div class="header">
    <div class="header-wrapper">
        <div class="left">
            <div class="label">Name</div>
        </div>
        <div class="right">
            <div class="input-cont">
                <input id="INPUTBOX" class="search-input" placeholder="Search...">
            </div>
        </div>
    </div>
    <div class="pkg-list">
"""

    for kind, path in walkDir(hdir & "/.nodecliac/registry"):
        let parts = splitPath(path)
        names.add(parts.tail)

    names.sort()
    for n in names:
        html &= "<div class=\"row\" id=\"vrow-" & n &  "\">"
        html &= "<div class=\"label\">" & n & "</div>"
        html &= "</div>"
    html &= "</div></div>"

    app.js(innerHTML(app, "view"))
    app.js(app.addHtml("#view", html, position=afterbegin))


getPackages()

app.bindProcs("api"):
    # Open provided url in user's browser.
    #
    # @param  {string} url - The URL to open.
    # @return {nil} - Nothing is returned.
    proc open(url: string) =
        # [https://github.com/webview/webview/issues/113]
        openDefaultBrowser(url)

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


# import libfswatch
# import libfswatch/fswatch
# proc callback(event: fsw_cevent, event_num: cuint) =
#     echo event.path
# let hdir = os.getEnv("HOME")
# var mon = newMonitor()
# mon.addPath(hdir & "/.nodecliac/registry")
# mon.setCallback(callback)
# mon.start()

app.run()
app.exit()
