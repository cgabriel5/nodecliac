#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import platform
from pathlib import Path

# Builtin variables.
def builtins(cmdname):
    return {
        "HOME": str(Path.home()),
        # [https://stackoverflow.com/a/1857]
        "OS": platform.system().lower(),
        "COMMAND": cmdname,
        "PATH": f"~/.nodecliac/registry/{cmdname}"
    }
