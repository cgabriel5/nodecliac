#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from issue import Issue
from string_builder import StringBuilder

def vsetting(token, text, LINESTARTS, filename):
    start = token["start"]
    end = token["end"]
    line = token["line"]
    index = token["start"]

    settings = ["compopt", "filedir", "disable", "placehold"]

    setting = StringBuilder()
    for i in range(start + 1, end + 1):
        setting.append(text[i])

    # Warn if setting is not a supported setting.
    if setting not in settings:
        message = "Unknown setting: '@" + str(setting) + "'"
        Issue().warn(filename, line, index - LINESTARTS[line], message)

def vvariable(token, text, LINESTARTS, filename):
    start = token["start"]
    end = token["end"]
    line = token["line"]
    index = token["start"]

    # Error when variable starts with a number.
    if text[start + 1].isdigit():
        message = f"Unexpected: '{text[start + 1]}'"
        message += f"\n\033[1;36mInfo\033[0m: Variable cannot begin with a number."
        Issue().error(filename, line, index - LINESTARTS[line], message)

def vstring(token, text, LINESTARTS, filename):
    start = token["start"]
    end = token["end"]
    line = token["lines"][0]
    index = token["start"]

    # Warn when string is empty.
    # [TODO] Warn if string content is just whitespace?
    if end - start == 1:
        message = f"Empty string"
        Issue().warn(filename, line, index - LINESTARTS[line], message)

    # Error if string is unclosed.
    if token["lines"][1] == -1:
        message = f"Unclosed string"
        Issue().error(filename, line, index - LINESTARTS[line], message)
