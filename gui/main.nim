import os, algorithm, browsers, strutils, webgui

# macos dimensions width: 725, height: 500
let app = newWebView(currentHtmlPath("views/index.html"),
    debug=true, title="nodecliac GUI",
    width=1000, height=800,
    minWidth=600, minHeight=600,
    resizable=true,
    cssPath=currentHtmlPath("css/empty.css")
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
<div class="vi-row-header">
    <div style="padding:5px 0;">
        <div class="vi-label-header">Name</div>
    </div>
    <div class="">
        <div class="input-cont"><input id="INPUTBOX" class="search-input" placeholder="Search..."></div>
    </div>
</div>
    """

    for kind, path in walkDir(hdir & "/.nodecliac/registry"):
        let parts = splitPath(path)
        names.add(parts.tail)

    names.sort()
    for n in names:
        html &= "<div class=\"vi-row\" id=\"vrow-" & n &  "\">"
        html &= "<div class=\"vi-label\">" & n & "</div>"
        html &= "</div>"
    app.js(innerHTML(app, "view"))
    app.js(app.addHtml("#view", html, position=afterbegin))

getPackages()

proc openBrowserURL() =
    # [https://github.com/webview/webview/issues/113]
    openDefaultBrowser("https://github.com/cgabriel5/nodecliac")

proc showAboutWindow() =
    let about = newWebView(currentHtmlPath("views/about.html"), title="nodecliac GUI", width=600, height=350, resizable=false, cssPath=currentHtmlPath("css/empty.css"))
    about.run()
    about.exit()

app.bindProcs("api"):
    proc openURL() = openBrowserURL()
    proc showAbout() = showAboutWindow()

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
