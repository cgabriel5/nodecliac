#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from io import StringIO

# [https://www.delftstack.com/howto/python/stringbuilder-in-python/]
# [https://docs.python.org/3/library/io.html]
# [https://blog.ganssle.io/articles/2019/11/string-concat.html]
class StringBuilder:
    _file_str = None

    def __init__(self):
        self._file_str = StringIO()

    def append(self, s):
        self._file_str.write(s)

    def __str__(self):
        return self._file_str.getvalue()
