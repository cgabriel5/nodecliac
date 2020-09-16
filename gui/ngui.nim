import os, osproc, webgui, strutils, browsers, algorithm
# import libfswatch
# import libfswatch/fswatch

# proc callback(event: fsw_cevent, event_num: cuint) =
#     echo event.path

# let hdir = os.getEnv("HOME")
# var mon = newMonitor()
# mon.addPath(hdir & "/.nodecliac/registry")
# mon.setCallback(callback)
# mon.start()


# echo currentHtmlPath()
# echo currentHtmlPath("app.css")

# macos dimensions width: 725, height: 500
let app = newWebView(currentHtmlPath("index.html"), debug=true, title="nodecliac GUI", width=1000, height=800, minWidth=600, minHeight=600, resizable=true, cssPath=currentHtmlPath("empty.css"))
# setTrayIcon(app, path="/opt/lampp/htdocs/projects/nodecliac/gui/LOGO2.png", tooltip="nodecliac GUI")

# setTheme(app, dark=false)

echo app.url

template justDoIt(command: string) =
  const
    style = """style="border: 1px solid white;""""
  let
    html = "<textarea class=\"output\" rows=12 readonly " & style & ">" & execProcess("choosenim --noColor " & command) & "</textarea>"
  app.js(app.addHtml("#versions", html, position=afterbegin))


template justDoItVersion(command: string) =
  const
    style = """style="border: 1px solid white; text-align: center; overflow: hidden;""""
  let
    html = "<textarea class=\"output\" rows=1 readonly " & style & ">" & execProcess("choosenim --noColor " & command) & "</textarea>"
  app.js(app.addHtml("#versions", html, position=afterbegin))




template addHtmlS(_: Webview; id, html: string, position = beforeEnd): string =
  ## Appends **HTML** to an Element by `id` at `position`, uses `insertAdjacentHTML()`, JavaScript side.
  ## * https://developer.mozilla.org/en-US/docs/Web/API/Element/insertAdjacentHtml
  assert id.len > 0, "ID must not be empty string, must have an ID"
  "document.querySelector(" & id & ").insertAdjacentHTML('" & $position & "',`" & html.replace('`', ' ') & "`);"




proc addTTT() =
    echo "???????"
    # let ssss = "let last_clicked = null;document.addEventListener('mousedown', function(e) {const target = e.target; if (last_clicked) { last_clicked.classList.remove('vi-row-selected'); } if (target.classList.contains('vi-row')) {target.classList.toggle('vi-row-selected'); last_clicked = target;}}, false);"
    # # app.js(app.addHtml("#head", ssss, position=beforeend))
    # # app.js(ssss)
    # # app.js(app.addHtml("#head", ssss, position=beforeend))

    # # app.js("document.body.style.opacity = \"0.5\";")
    # # app.js(addHtmlS("document.querySelector("head"). = \"0.5\";"))
    # # app.js(addHtmlS(app, "head", ssss, beforeend))
    # app.js(ssss)
    echo "DONE"






proc innerHTML(_: Webview; id: string, html=""): string =
  "document.getElementById('" & id & "').innerHTML = \"\";"

template clearHTML(id: string) =
  app.js(innerHTML(app, id, ""))


proc getPackages() =
    let hdir = os.getEnv("HOME")
    var names: seq[string] = @[]
    # var html = "<div class=\"vi-row-header\"><div class=\"vi-label-header\">Name</div></div>"


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
        # echo parts.tail
        names.add(parts.tail)
        # html &= "<div class=\"vi-row\">"
        # html &= "<div class=\"vi-label\">" & parts.tail & "</div>"
        # html &= "</div>"

    names.sort()

    for n in names:
        # if n == "nodecliac":
            # html &= "<div class=\"vi-row vi-row-selected\">"
        # else:
            # html &= "<div class=\"vi-row\">"

        html &= "<div class=\"vi-row\" id=\"vrow-" & n &  "\">"

        # html &= "<div class=\"vi-row-cb\"><input type=\"checkbox\" checked></div> <div class=\"vi-label\">" & n & "</div>"
        html &= "<div class=\"vi-label\">" & n & "</div>"
        html &= "</div>"


    app.js(innerHTML(app, "view"))
    app.js(app.addHtml("#view", html, position=afterbegin))


getPackages()

proc listRegistry(id: string) =
  # let o = execProcess("nodecliac registry")
  # echo o

  # let h = "<textarea class=\"output\" rows=1 readonly " & style & ">" & execProcess("choosenim --noColor " & command) & "</textarea>"

  # let h = "document.getElementById('" & id & "').innerHTML = \"<div>" & o & "</div>\";"
  # let html = "<div><p><code>" & o & "</code></p></div>;"


  const
    style = """style="border: 1px solid white; min-height: 350px;min-width:300px;""""
  let
    html = "<textarea class=\"output\" readonly " & style & ">" & execProcess("nodecliac registry") & "</textarea>"
  app.js(app.addHtml("#versions", html, position=afterbegin))


  # let html = "<textarea>" & o & "</textarea>;"
  # echo html
  # app.js(h)
  # app.js(app.addHtml("#versions", html, position=afterbegin))

const selectVersion = """
<div style="border: 1px solid white; padding: 20px; text-align: center;">
  <p>Click on the version to <b>$1</b></p>
  <ul style="width: 300px; margin-left: auto; margin-right: auto;">
    $2
  </ul>
</div>
"""
proc versions(action: string) =
  const
    style = """style="background-color: white; cursor: pointer; padding: 5px; color: black; border-radius: 2px;""""
  var
    html: string
    avail: bool

  for line in execProcess("choosenim --noColor show").split("\n"):
    if line.contains("Versions:"):
      avail = true
      continue

    if not avail or line == "": # or (action == "select" and line.contains("*")):
      continue

    html.add("<p onclick=\"api.cn" & capitalizeAscii(action) & "Do(this.textContent)\" " & style & ">" & line.strip() & "</p>")

  app.js(app.addHtml("#versions", selectVersion.format(toUpperAscii(action), html), position=afterbegin))


proc install() =
  const
    style = """style="background-color: white; cursor: pointer; padding: 5px; color: black; border-radius: 2px;""""
  var
    html: string
    avail: bool

  for line in execProcess("choosenim --noColor versions").split("\n"):
    if line.contains("Available:"):
      avail = true
      continue

    if not avail or line == "": # or (action == "select" and line.contains("*")):
      continue

    html.add("<p onclick=\"api.cnInstallDo(this.textContent)\" " & style & ">" & line.strip() & "</p>")

  app.js(app.addHtml("#versions", selectVersion.format(toUpperAscii("install"), html), position=afterbegin))


proc openBrowserURL() =
    # [https://github.com/webview/webview/issues/113]
    openDefaultBrowser("https://github.com/cgabriel5/nodecliac")

proc showAboutWindow() =
    let about = newWebView(currentHtmlPath("about.html"), title="nodecliac GUI", width=600, height=350, resizable=false, cssPath=currentHtmlPath("empty.css"))
    about.run()
    about.exit()

# proc eventClickBody(a: string) =
#     echo "BODY CLICKED"
#     # echo app.js("console.log('Nim is awesome')")

app.bindProcs("api"):
  proc openURL() = openBrowserURL()
  proc showAbout() = showAboutWindow()
  # proc clickBody() = eventClickBody("body")
  # proc callback() = echo execCmd("echo 'Nim is awesome'")
  # proc callback() = echo app.js("console.log('Nim is awesome')")
  proc callback() = addTTT()


  proc cnRegistry()           = listRegistry("versions")
  proc cnClear()              = clearHTML "versions"
  proc cnShow()               = justDoIt "show"
  proc cnListInstalled()      = justDoIt "versions --installed"
  proc cnListAll()            = justDoIt "versions"
  proc cnSelect()             = versions("select")
  # proc cnSelectDo(s: string)  = justDoItVersion s.strip().multiReplace([("#", ""), ("*", ""), ("(latest)", "")])
  proc cnUpdate()             = versions("update")
  # proc cnUpdateDo(s: string)  = justDoIt "update " & s.strip().multiReplace([("#", ""), ("*", ""), ("(latest)", "")])
  proc cnInstall()            = install()
  # proc cnInstallDo(s: string) = justDoIt s.strip().multiReplace([("#", ""), ("*", ""), ("(latest)", "")])

# versions("select")
app.run()
app.exit()
