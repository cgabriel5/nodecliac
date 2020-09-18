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

proc getPackages() =
    var html = ""
    let hdir = os.getEnv("HOME")
    var names: seq[string] = @[]

    for kind, path in walkDir(hdir & "/.nodecliac/registry"):
        let parts = splitPath(path)
        names.add(parts.tail)

    names.sort()
    for n in names:
        html &= "<div class=\"pkg-entry\" id=\"pkg-entry-" & n &  "\">"
        html &= "<div class=\"pkg-entry-label\">" & n & "</div>"
        html &= "</div>"

    app.js(
        app.setText("#pkg-list-entries", "") & ";" &
        app.addHtml("#pkg-list-entries", html, position=afterbegin)
    )

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

getPackages()
app.run()
app.exit()
