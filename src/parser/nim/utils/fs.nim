from strutils import split
from os import paramStr, paramCount, splitFile, DirSep
from streams import close, readAll, write, newFileStream, openFileStream

type FileInfo = ref object
    name*, dirname*, ext*, path*: string

# Get file path information (i.e. file name and directory path).
#
# @param  {string} p - The complete file path.
# @return {object} - Object containing file path components.
proc info*(p: string): FileInfo =
    new(result)

    let (dir, name, ext) = splitFile(p)
    result.dirname = dir
    result.path = p

    if ext != "":
        result.name = name & ext
        result.ext = ext[1 .. ext.len-1]
    else:
        let path_parts = p.split(DirSep)
        let name = path_parts[^1]
        let name_parts = name.split(".")
        if name_parts.len > 0:
            result.name = name
            result.ext = name_parts[^1]

# Returns file contents.
#
# @param  {string} p - The path of file to read.
# @return {string} - The file contents.
proc read*(p: string): string =
    # Use stream to gulp file contents.
    var strm = openFileStream(p, fmRead)
    result = ""
    if not isNil(strm):
        result = strm.readAll()
        strm.close()

# Writes contents to file.
#
# @param  {string} p - The path of file to read.
# @param  {contents} contents - The data to write to file.
# @return {string} - The file contents.
proc write*(p: string, contents: string) =
    var strm = newFileStream(p, fmWrite)
    if not isNil(strm):
        strm.write(contents)
        strm.close()
