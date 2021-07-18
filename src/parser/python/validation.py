#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from issue import Issue
from string_builder import StringBuilder

def vsetting(S):
    token = S["tokens"][S["tid"]]
    start = token["start"]
    end = token["end"]
    line = token["line"]
    index = token["start"]

    settings = ["compopt", "filedir", "disable", "placehold", "test"]

    setting = StringBuilder()
    for i in range(start + 1, end + 1):
        setting.append(S["text"][i])

    # Warn if setting is not a supported setting.
    if str(setting) not in settings:
        message = "Unknown setting: '" + str(setting) + "'"

        if line not in S["warnings"]: S["warnings"][line] = []
        S["warnings"][line].append([S["filename"], line, index - S["LINESTARTS"][line], message])
        S["warn_lines"].add(line)

def vvariable(S):
    token = S["tokens"][S["tid"]]
    start = token["start"]
    end = token["end"]
    line = token["line"]
    index = token["start"]

    # Error when variable starts with a number.
    if S["text"][start + 1].isdigit():
        message = "Unexpected: '" + S["text"][start + 1] + "'"
        message += "\n\033[1;36mInfo\033[0m: Variable cannot begin with a number."
        Issue().error(S["filename"], line, index - S["LINESTARTS"][line], message)

def vstring(S):
    token = S["tokens"][S["tid"]]
    start = token["start"]
    end = token["end"]
    line = token["lines"][0]
    index = token["start"]

    # Warn when string is empty.
    # [TODO] Warn if string content is just whitespace?
    if end - start == 1:
        message = "Empty string"

        if line not in S["warnings"]: S["warnings"][line] = []
        S["warnings"][line].append([S["filename"], line, index - S["LINESTARTS"][line], message])
        S["warn_lines"].add(line)

    # Error if string is unclosed.
    if token["lines"][1] == -1:
        message = "Unclosed string"
        Issue().error(S["filename"], line, index - S["LINESTARTS"][line], message)

def vsetting_aval(S):
    token = S["tokens"][S["tid"]]
    start = token["start"]
    end = token["end"]
    line = token["line"]
    index = token["start"]

    values = ["true", "false"]

    value = StringBuilder()
    for i in range(start, end + 1):
        value.append(S["text"][i])

    # Warn if values is not a supported values.
    if str(value) not in values:
        message = "Invalid setting value: '" + str(value) + "'"
        Issue().error(S["filename"], line, index - S["LINESTARTS"][line], message)
