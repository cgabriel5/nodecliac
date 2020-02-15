from strutils import split
from os import getEnv, paramStr, paramCount, splitFile, DirSep
from streams import close, readAll, write, newFileStream, openFileStream

# Expands starting tilde ('~') in path.
#
# @param {string} 1) - Path to expand.
# @return {string} - The expanded path.
#
# @resource: [https://nim-lang.org/docs/os.html#expandTilde%2Cstring]
proc expand_tilde*(p: string): string =
    result = p
    if p[0] == '~': result = os.getEnv("HOME") & p[1 .. p.high]


# Get file path information (i.e. file name and directory path).
#
# @param  {string} p - The complete file path.
# @return {object} - Object containing file path components.
proc info*(p: string): any =
    let c = splitFile(p)

    type FileInfo = object
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
    result = ""
    if not isNil(strm):
        result = strm.readAll()
        strm.close()

#  Writes contents to file.
#
#  @param  {string} p - The path of file to read.
#  @param  {contents} contents - The data to write to file.
#  @return {string} - The file contents.
proc write*(p: string, contents: string) =
    var strm = newFileStream(p, fmWrite)
    if not isNil(strm):
        strm.write(contents)
        strm.close()
