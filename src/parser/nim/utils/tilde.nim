import os, strutils

let hdir = os.getEnv("HOME")

# Expands starting tilde ('~') in path.
#
# @param {string} 1) - Path to expand.
# @return {string} - The expanded path.
#
# @resource: [https://nim-lang.org/docs/os.html#expandTilde%2Cstring]
proc expand*(p: string): string =
    runnableExamples:
      doAssert expand("") == ""
      doAssert expand("~") == hdir
      doAssert expand("~/Desktop") == joinPath(hdir, "Desktop")

    result = p
    if p.len == 0: result = ""
    elif p[0] == '~': result = hdir & p[1 .. p.high]

# Collapse starting home dir in a path to '~'.
#
# @param  {string} p - The path.
# @return {undefined} - Nothing is returned.
proc shrink*(p: string): string =
    runnableExamples:
      doAssert shrink("") == ""
      doAssert shrink(hdir) == "~"
      doAssert shrink(hdir & "/Desktop") == "~/Desktop"

    result = p
    if p.startsWith(hdir): result = "~" & p[hdir.len .. ^ 1]
