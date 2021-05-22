#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os

# Get file path information (i.e. file name and directory path).
#
# @param  {string} p - The complete file path.
# @return {object} - Object containing file path components.
def info(p):
    FileInfo = {
        "name": "",
        "dirname": "",
        "ext": "",
        "path": ""
    }

    def splitfile(p):
        head, tail = os.path.split(p)
        name, ext = os.path.splitext(tail)
        return (head, name, ext)

    (head, name, ext) = splitfile(p)

    FileInfo["dirname"] = head
    FileInfo["path"] = p

    if ext:
        FileInfo["name"] = name + ext
        FileInfo["ext"] = ext[1:len(ext)]
    else:
        path_parts = p.split(os.path.sep)
        name = path_parts[-1]
        name_parts = name.split('.')
        if len(name_parts):
            FileInfo["name"] = name
            FileInfo["ext"] = name_parts[-1]

    return FileInfo
