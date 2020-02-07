from os import
    getEnv,
    paramStr,
    paramCount,
    splitFile,
    DirSep
from re import
    re,
    replace
from strutils import split
import streams

# Expands starting tilde ('~') to user's home directory.
#
# @param {string} 1) - Path to expand.
# @return {string} - The expanded path.
proc expand_tilde*(p: string): string =
    return p.replace(re("^~"), os.getEnv("HOME"))

# Get file path information (i.e. file name and directory path).
#
# @param  {string} p - The complete file path.
# @return {object} - Object containing file path components.
proc info*(p: string): any =
    let c = splitFile(p)

    type FileInfo = ref object of RootObj
        name*: string
        dirname*: string
        ext*: string
        path*: string

    var fobject = FileInfo(dirname: c.dir, path: p)
    let ext = c.ext;

    if ext != "":
        fobject.name = c.name & ext
        fobject.ext = ext[1..ext.len-1]
    else:
        let path_parts = p.split(DirSep)
        let name = path_parts[^1]
        let name_parts = name.split(".")
        if name_parts.len > 0:
            fobject.name = name
            fobject.ext = name_parts[^1]
    return fobject

#  Returns file contents.
#
#  @param  {string} p - The path of file to read.
#  @return {string} - The file contents.
proc read*(p: string): string =
    # Use stream to gulp file contents.
    var strm = openFileStream(p, fmRead)
    let r = strm.readAll()
    strm.close()
    return r
