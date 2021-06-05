#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re
import os
import time
import hashlib
import functools
from datetime import datetime
from collections import OrderedDict

def acdef(branches, cchains, flags, settings, S):

    ubids = S["ubids"]
    text = S["text"]
    tokens = S["tokens"]

    oSets = {}
    oKeywords = {}
    oDefaults = {}
    oFiledirs = {}
    oContexts = {}

    oSettings = OrderedDict()
    settings_count = 0
    oTests = []
    oPlaceholders = {}
    omd5Hashes = {}
    acdef = ""
    acdef_lines = []
    config = ""
    defaults = ""
    filedirs = ""
    contexts = ""
    has_root = False

    # Escape '+' chars in commands. [https://stackoverflow.com/a/678242]
    rcmdname = re.sub(r'\+', "\\+", os.path.splitext(S["filename"])[0])
    r = re.compile(f"^({rcmdname}|[-_a-zA-Z0-9]+)")

    date = time.time()
    dt = datetime.fromtimestamp(date)
    timestamp = round(date)
    # [https://www.programiz.com/python-programming/datetime/strftime]
    datestring = dt.strftime("%a %b %-d %Y %H:%M:%S")
    ctime = datestring + " (" + str(timestamp) + ")"
    header = "# DON'T EDIT FILE —— GENERATED: " + ctime + "\n\n"
    if S["args"]["test"]: header = ""

    def tkstr(tid):
        if tid == -1: return ""
        # Return interpolated string for string tokens.
        if tokens[tid]["kind"] == "tkSTR": return tokens[tid]["$"]
        return text[tokens[tid]["start"]:tokens[tid]["end"] + 1]

    def aobj(s):
        return { "val": s.lower() }

    def asort(a, b):
        if a["val"] != b["val"]:
            if a["val"] < b["val"]: result = -1
            else: result = 1
        else: result = 0

        if result == 0 and a.get("single", False) and b.get("single", False):
            if a["orig"] < b["orig"]: result = 1
            else: result = 0
        return result

    # compare function: Gives precedence to flags ending with '=*' else
    #     falls back to sorting alphabetically.
    #
    # @param  {string} a - Item a.
    # @param  {string} b - Item b.
    # @return {number} - Sort result.
    #
    # Give multi-flags higher sorting precedence:
    # @resource [https://stackoverflow.com/a/9604891]
    # @resource [https://stackoverflow.com/a/24292023]
    # @resource [http://www.javascripttutorial.net/javascript-array-sort/]
    # let sort = (a, b) => ~~b.endsWith("=*") - ~~a.endsWith("=*") || asort(a, b)
    def fsort(a, b):
        result = b["m"] - a["m"]
        if result == 0: result = asort(a, b)
        return result

    def fobj(s):
        o = { "val": s.lower(), "m": int(s.endswith("=*")) }
        if s[1] != '-':
            o["orig"] = s
            o["single"] = True
        return o

    # Uses map sorting to reduce redundant preprocessing on array items.
    #
    # @param  {array} A - The source array.
    # @param  {function} comp - The comparator function to use.
    # @return {array} - The resulted sorted array.
    #
    # @resource [https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/sort]
    def mapsort(A, comp, comp_obj):
        T = [] # Temp array.
        # [https://stackoverflow.com/a/10712044]
        R = [None] * len(A) # Result array.
        for i, a in enumerate(A):
            obj = comp_obj(a)
            obj["i"] = i
            T.append(obj)
        # [https://stackoverflow.com/a/46320068]
        T.sort(key=functools.cmp_to_key(comp))
        for i in range(len(T)): R[i] = A[T[i]["i"]]
        return R

    # Removes first command in command chain. However, when command name
    # is not the main command in (i.e. in a test file) just remove the
    # first command name in the chain.
    #
    # @param  {string} command - The command chain.
    # @return {string} - Modified chain.
    def rm_fcmd(chain):
        return re.sub(r, "", chain)

    def get_cmdstr(start, stop):
        output = []
        allowed_tk_types = ("tkSTR", "tkDLS")
        for tid in range(start, stop):
            if S["tokens"][tid]["kind"] in allowed_tk_types:
                if output and output[-1] == "$": output[-1] = "$" + tkstr(tid)
                else: output.append(tkstr(tid))

        return "$({})".format(",".join(output))

    def processflags(gid, flags, queue_flags, recunion=False, recalias=False):
        unions = []
        for flg in flags:
            tid = flg["tid"]
            assignment = tkstr(flg["assignment"])
            boolean = tkstr(flg["boolean"])
            alias = tkstr(flg["alias"])
            flag = tkstr(tid)
            ismulti = tkstr(flg["multi"])
            union = flg["union"] != -1
            values = flg["values"]
            kind = tokens[tid]["kind"]

            if alias and not recalias:
                processflags(gid, [flg], queue_flags, recalias=True)

            # Skip union logic on recursion.
            if not recalias and kind != "tkKYW" and not recunion:
                if union:
                    unions.append(flg)
                    continue
                elif unions:
                    for uflg in unions:
                        uflg["values"] = values
                        processflags(gid, [uflg], queue_flags, recunion=True)
                    unions.clear()

            if recalias:
                oKeywords[gid]["context"][f"{{{flag.strip('-')}|{alias}}}"] = 1
                flag = "-" + alias

            if kind == "tkKYW":
                if values:
                    if len(values[0]) == 1:
                        value = re.sub(r"\s", "", tkstr(values[0][0]))
                        if flag == "context": value = value[1:-1]
                        oKeywords[gid][flag][value] = 1
                    else:
                        value = get_cmdstr(values[0][1] + 1, values[0][2])
                        oKeywords[gid][flag][value] = 1
                continue

            # Flag with values: build each flag + value.
            if values:
                # Baseflag: add multi-flag indicator?
                # Add base flag to Set (adds '--flag=' or '--flag=*').
                queue_flags[f"{flag}={'*' if ismulti else ''}"] = 1
                mflag = f"{flag}={'' if ismulti else '*'}"
                if mflag in queue_flags: del queue_flags[mflag]

                for value in values:
                    if len(value) == 1: # Single
                        queue_flags[flag + assignment + tkstr(value[0])] = 1

                    else: # Command-string
                        cmdstr = get_cmdstr(value[1] + 1, value[2])
                        queue_flags[flag + assignment + cmdstr] = 1

            else:
                if not ismulti:
                    if boolean: queue_flags[flag + "?"] = 1
                    elif assignment: queue_flags[flag + "="] = 1
                    else: queue_flags[flag] = 1
                else:
                    queue_flags[flag + "=*"] = 1
                    queue_flags[flag + "="] = 1

    def populate_keyword_objs(gid, chain):
        for kw in oKeywords[gid]:
            container = None
            if kw == "default":   container = oDefaults
            elif kw == "filedir": container = oFiledirs
            elif kw == "context": container = oContexts
            elif kw == "exclude": continue
            else: continue

            if chain not in container: container[chain] = []
            values = list(oKeywords[gid][kw])
            if not values: continue

            container[chain].append(
                ";".join(values) if kw == "context" else values[-1]
            )

    def populate_chain_flags(gid, chain, container):
        if chain not in excludes:
            processflags(gid, ubflags, container)

        if chain not in oSets:
            oSets[chain] = container
        else: oSets[chain].update(container)

    def kwstr(kwtype, container):
        output = []
        chains = mapsort([c for c in container if container[c]], asort, aobj)
        cl = len(chains) - 1
        tstr = "{} {} {}"
        for i, chain in enumerate(chains):
            value = (container[chain][0] if kwtype != "context"
                else "\"" + ";".join(container[chain]) + "\"")
            output.append(tstr.format(rm_fcmd(chain), kwtype, value))
            if i < cl: output.append("\n")

        return "\n\n" + "".join(output) if output else ""

    def make_chains(ccids):
        slots = []
        chains = []
        groups = []
        grouping = False

        for cid in ccids:
            if cid == -1: grouping = not grouping

            if not grouping and cid != -1:
                slots.append(tkstr(cid))
            elif grouping:
                if cid == -1:
                    slots.append('?')
                    groups.append([])
                else: groups[-1].append(tkstr(cid))

        tstr = ".".join(slots)

        for group in groups:
            if not chains:
                for command in group:
                    chains.append(tstr.replace('?', command, 1))
            else:
                tmp_cmds = []
                for chain in chains:
                    for command in group:
                        tmp_cmds.append(chain.replace('?', command))
                chains = tmp_cmds

        if not groups: chains.append(tstr)

        return chains

    # Start building acmap contents. -------------------------------------------

    excludes = [] # [TODO] Get exclude command chains from parser.
    # Collect all universal block flags.
    ubflags = [flg for ubid in ubids for flg in flags[ubid]]

    for i, group in enumerate(cchains):

        oKeywords[i] = {
            "default": OrderedDict(),
            "filedir": OrderedDict(),
            "context": OrderedDict(),
            "exclude": OrderedDict()
        }

        for ccids in group:
            for chain in make_chains(ccids):
                if chain == "*": continue

                gflags = flags.get(i, [])
                container = {}
                processflags(i, gflags, container)
                populate_chain_flags(i, chain, container)
                populate_keyword_objs(i, chain)

                # Create missing parent chains.
                commands = re.split(r'(?<!\\)\.', chain)
                commands.pop() # Remove last command (already made).
                for _ in range(len(commands) - 1, -1, -1):
                    rchain = ".".join(commands) # Remainder chain.

                    if rchain not in oSets:
                        container = {}
                        populate_chain_flags(i, rchain, container)
                        if container: populate_keyword_objs(i, rchain)

                    commands.pop() # Remove last command.

    defaults = kwstr("default", oDefaults)
    filedirs = kwstr("filedir", oFiledirs)
    contexts = kwstr("context", oContexts)

    # Populate settings object.
    for setting in settings:
        name = tkstr(setting[0])[1:]
        if name == "test": oTests.append(re.sub(r";\s+", ";", tkstr(setting[2])))
        else: oSettings[name] = tkstr(setting[2]) if len(setting) > 1 else ""

    # Build settings contents.
    settings_count = len(oSettings)
    settings_count -= 1
    for setting in oSettings:
        config += f"@{setting} = {oSettings[setting]}"
        if settings_count: config += "\n"
        settings_count -= 1

    placehold = "placehold" in oSettings and oSettings["placehold"] == "true"
    for key in oSets:
        flags = "|".join(mapsort(list(oSets[key].keys()), fsort, fobj))
        if not flags: flags = "--"

        # Note: Placehold long flag sets to reduce the file's chars.
        # When flag set is needed its placeholder file can be read.
        if placehold and len(flags) >= 100:
            if flags not in omd5Hashes:
                # [https://stackoverflow.com/a/65613163]
                md5hash = hashlib.md5(flags.encode()).hexdigest()[26:]
                oPlaceholders[md5hash] = flags
                omd5Hashes[flags] = md5hash
                flags = "--p#" + md5hash
            else: flags = "--p#" + omd5Hashes[flags]

        row = f"{rm_fcmd(key)} {flags}"

        # Remove multiple ' --' command chains. Shouldn't be the
        # case but happens when multiple main commands are used.
        if row == " --" and not has_root: has_root = True
        elif row == " --" and has_root: continue

        acdef_lines.append(row)

    # If contents exist, add newline after header.
    sheader = re.sub(r"\n$", "", header)
    acdef_contents = "\n".join(mapsort(acdef_lines, asort, aobj))
    acdef = header + acdef_contents if acdef_contents else sheader
    config = header + config if config else sheader

    tests_tstr = "#!/bin/bash\n\n{}tests=(\n{}\n)"
    tests = tests_tstr.format(header, "\n".join(oTests)) if oTests else ""

    return (
        acdef,
        config,
        defaults,
        filedirs,
        contexts,
        "", # formatted
        oPlaceholders,
        tests
    )
