from strutils import split
from os import paramStr, paramCount, splitFile, DirSep,
    setFilePermissions, FilePermission
from streams import close, readAll, write, newFileStream, openFileStream

type FileInfo = ref object
    name*, dirname*, ext*, path*: string

# Convenience func to convert Unix like file permission to ``set[FilePermission]``.
#
# @param  {number} perm - The permissions in octal form.
# @resource [https://github.com/nim-lang/fusion/blob/master/src/fusion/filepermissions.nim]
# @resource [https://forum.nim-lang.org/t/7476]
proc toFilePermissions*(perm: Natural): set[FilePermission] =
    var perm = uint(perm)
    for permBase in [fpOthersExec, fpGroupExec, fpUserExec]:
        if (perm and 1) != 0: result.incl permBase         # Exec
        if (perm and 2) != 0: result.incl permBase.succ()  # Read
        if (perm and 4) != 0: result.incl permBase.succ(2) # Write
        perm = perm shr 3  # Shift to next permission group

# Convenience func to convert ``set[FilePermission]`` to Unix like file permission.
#
# @param  {set} perm - The permissions in a set[FilePermission].
# @resource [https://github.com/nim-lang/fusion/blob/master/src/fusion/filepermissions.nim]
# @resource [https://forum.nim-lang.org/t/7476]
proc fromFilePermissions*(perm: set[FilePermission]): uint =
    if fpUserExec in perm:    inc result, 0o100  # User
    if fpUserWrite in perm:   inc result, 0o200
    if fpUserRead in perm:    inc result, 0o400
    if fpGroupExec in perm:   inc result, 0o010  # Group
    if fpGroupWrite in perm:  inc result, 0o020
    if fpGroupRead in perm:   inc result, 0o040
    if fpOthersExec in perm:  inc result, 0o001  # Others
    if fpOthersWrite in perm: inc result, 0o002
    if fpOthersRead in perm:  inc result, 0o004

# Convenience proc for `os.setFilePermissions("file.ext", filepermissions.toFilePermissions(0o666))`
# to change file permissions using Unix like octal file permission.
#
# @param  {string} path - The file path.
# @param  {number} permissions - The permissions in octal form.
# @resource [https://github.com/nim-lang/fusion/blob/master/src/fusion/filepermissions.nim]
# @resource [https://forum.nim-lang.org/t/7476]
proc chmod*(path: string; permissions: Natural) {.inline.} =
    setFilePermissions(path, toFilePermissions(permissions))

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
