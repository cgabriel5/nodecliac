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
    oFlags = {}
    oParents = {}
    NOFLAGS = {"--": 1}

    oKeywords = {}
    oDefaults = {}
    oFiledirs = {}
    oExcludes = {}
    oContexts = {}

    oSettings = OrderedDict()
    settings_count = 0
    oTests = []
    oPlaceholders = {}
    omd5Hashes = {}
    count = 0
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

    def processflags(gid, flags, queue_flags, recunion=False):
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

            # Skip union logic on recursion.
            if kind != "tkKYW":
                if not recunion and union:
                    unions.append(flg)
                    continue
                if not recunion and unions and not union:
                    for uflg in unions:
                        uflg["values"] = values
                        processflags(gid, unions, queue_flags, recunion=True)
                    unions.clear()

            nonlocal oKeywords
            if alias:
                # nonlocal oKeywords
                if gid not in oKeywords:
                    oKeywords[gid] = {}
                container = oKeywords.get(gid, {})

                if "context" not in container: container["context"] = []
                container["context"].append(f"{{{flag.strip('-')}|{alias}}}")

            if kind == "tkKYW":
                # nonlocal oKeywords
                if gid not in oKeywords:
                    oKeywords[gid] = {}
                container = oKeywords.get(gid, {})

                if values:
                    if len(values[0]) == 1:
                        if flag == "context":
                            if "context" not in container: container["context"] = []
                            container[flag].append(re.sub(r"\s", "", tkstr(values[0][0])[1:-1]))
                        else: container[flag] = re.sub(r"\s", "", tkstr(values[0][0]))
                    else:
                        strs = []
                        for tid in range(values[0][1]+1, values[0][2]):
                            if S["tokens"][tid]["kind"] in ("tkSTR", "tkDLS"):
                                if strs and strs[-1] == "$":
                                    strs[-1] = "$" + tkstr(tid)
                                else:
                                    strs.append(tkstr(tid))

                        container[flag] = "$(" + ",".join(strs) + ")"

                continue

            # Flag with values: build each flag + value.
            if values:
                # Baseflag: add multi-flag indicator?
                # Add base flag to Set (adds '--flag=' or '--flag=*').
                queue_flags[f"{flag}={'*' if ismulti else ''}"] = 1
                mflag = f"{flag}={'' if ismulti else '*'}"
                if mflag in queue_flags:
                    del queue_flags[mflag]

                if alias:

                    queue_flags[f"{'-' + alias}={'*' if ismulti else ''}"] = 1
                    mflag = f"{'-' + alias}={'' if ismulti else '*'}"
                    if mflag in queue_flags:
                        del queue_flags[mflag]

                for value in values:
                    if len(value) == 1: # Single
                        queue_flags[flag + assignment + tkstr(value[0])] = 1

                        if alias:
                            queue_flags['-' + alias + assignment + tkstr(value[0])] = 1

                    else: # Command-string
                        strs = []
                        for tid in range(value[1]+1, value[2]):
                            if S["tokens"][tid]["kind"] in ("tkSTR", "tkDLS"):
                                if strs and strs[-1] == "$":
                                    strs[-1] = "$" + tkstr(tid)
                                else:
                                    strs.append(tkstr(tid))

                        queue_flags[flag + assignment + "$(" + ",".join(strs) + ")"] = 1

                        if alias:
                            queue_flags['-' + alias + assignment + "$(" + ",".join(strs) + ")"] = 1

            else:
                if not ismulti:
                    if boolean: queue_flags[flag + "?"] = 1
                    elif assignment: queue_flags[flag + "="] = 1
                    else: queue_flags[flag] = 1
                else:
                    queue_flags[flag + "=*"] = 1
                    queue_flags[flag + "="] = 1

                if alias:
                    if not ismulti:
                        if boolean: queue_flags['-' + alias + "?"] = 1
                        elif assignment: queue_flags['-' + alias + "="] = 1
                        else: queue_flags['-' + alias] = 1
                    else:
                        queue_flags['-' + alias + "=*"] = 1
                        queue_flags['-' + alias + "="] = 1

    # Populate settings object.
    for setting in settings:
        name = tkstr(setting[0])[1:]
        if name == "test": oTests.append(re.sub(r";\s+", ";", tkstr(setting[2])))
        else: oSettings[name] = tkstr(setting[2]) if len(setting) > 1 else ""

    for i, group in enumerate(cchains):

        # Handle universal blocks.
        if i not in ubids:
            # Add missing group flags arrays.
            if i not in flags: flags[i] = []
            # Add universal flags to flags array
            for wid in ubids:
                for flg in flags[wid]:
                    flags[i].append(flg)

        if i in flags:

            queue_flags = {}
            processflags(i, flags[i], queue_flags)

            if queue_flags:
                oFlags[i] = queue_flags

        else:
            oFlags[i] = {}

        for chain in group:

            chains = []
            slots = []
            expand = False
            expandables = []
            indices = []

            for _, command in enumerate(chain):
                if command == -1:
                    if not expand: expand = True
                    else: expand = False

                if not expand and command != -1:
                    slots.append(tkstr(command))
                elif expand:
                    if command == -1:
                        slots.append("?")
                        expandables.append([])
                        indices.append(len(slots))
                    else:
                        expandables[-1].append(tkstr(command))

            template = ".".join(slots)

            for k, exgroup in enumerate(expandables):
                if not chains:
                    for m, command in enumerate(exgroup):
                        chains.append(template.replace('?', command, 1))

                else:
                    tmp_commands = []
                    for o, chain in enumerate(chains):
                        for command in exgroup:
                            tmp_commands.append(chains[o].replace('?', command))

                    chains = tmp_commands

            if not expandables:
                chains.append(template)

            for chain in chains:

                # Skip universal blocks here, add flags post loop.
                if chain == "*":
                    if i in oKeywords:
                        if "exclude" in oKeywords[i]:
                            row = oKeywords[i]["exclude"]
                            oExcludes[row[1:-1]] = 1

                    continue

                if i in oFlags:
                    if chain not in oSets:
                        oSets[chain] = oFlags[i].copy()
                    else:
                        oSets[chain].update(oFlags[i])
                else:
                    if chain not in oSets:
                        oSets[chain] = {}

                if i in oKeywords:
                    for row in oKeywords[i]:
                        container = None
                        if row == "default":
                            container = oDefaults
                        elif row == "filedir":
                            container = oFiledirs
                        elif row == "context":
                            container = oContexts
                        elif row == "exclude":
                            container = oExcludes

                        # [TODO] Find better way to do this.
                        if row == "context":
                            ctxs_list = ";".join(oKeywords[i][row])
                            if chain not in container: container[chain] = []
                            container[chain].append(ctxs_list)
                        else:
                            container[chain] = f"{row} {oKeywords[i][row]}"

                # Create missing parent chains.
                commands = re.split(r'(?<!\\)\.', chain)
                commands.pop() # Remove last command (already made).
                for _ in range(len(commands) - 1, -1, -1):
                    rchain = ".".join(commands) # Remainder chain.

                    if rchain not in oSets:
                        if not ubids:
                            oParents[rchain] = NOFLAGS
                        else:
                            rflags = []
                            oParents[rchain] = rflags

                            for wid in ubids:
                                if wid in oFlags:
                                    if rchain not in oSets:
                                        oSets[rchain] = oFlags[wid].copy()
                                    else:
                                        oSets[rchain].update(oFlags[wid])
                                else:
                                    if rchain not in oSets:
                                        oSets[rchain] = {}

                                if wid in oKeywords:
                                    for row in oKeywords[wid]:
                                        container = None
                                        if row == "default":
                                            container = oDefaults
                                        elif row == "filedir":
                                            container = oFiledirs
                                        elif row == "context":
                                            container = oContexts
                                        elif row == "exclude":
                                            container = oExcludes

                                        # [TODO] Find better way to do this.
                                        if row == "context":
                                            ctxs_list = ";".join(oKeywords[wid][row])
                                            if rchain not in container: container[rchain] = []
                                            container[rchain].append(ctxs_list)
                                        else:
                                            container[rchain] = f"{row} {oKeywords[wid][row]}"

                    commands.pop() # Remove last command.

    # Add parent chains.
    for _ in oParents:
        if _ not in oSets:
            oSets[_] = NOFLAGS

    # Build defaults contents.
    defs = mapsort(list(oDefaults.keys()), asort, aobj)
    dl = len(defs) - 1
    for i, __def in enumerate(defs):
        defaults += f"{rm_fcmd(__def)} {oDefaults[__def]}"
        if i < dl: defaults += "\n"
    if defaults: defaults = "\n\n" + defaults

    # Build defaults contents.
    fdirs = mapsort(list(oFiledirs.keys()), asort, aobj)
    fl = len(fdirs) - 1
    for i, __fdir in enumerate(fdirs):
        filedirs += f"{rm_fcmd(__fdir)} {oFiledirs[__fdir]}"
        if i < fl: filedirs += "\n"
    if filedirs: filedirs = "\n\n" + filedirs

    # Build contexts contents.
    ctxlist = []
    for context in oContexts: ctxlist.append(context)
    ctxs = mapsort(list(oContexts.keys()), asort, aobj)
    cl = len(ctxs) - 1
    for i, __ctx in enumerate(ctxs):
        ctxs_list = ";".join(oContexts[__ctx])
        contexts += f"{rm_fcmd(__ctx)} context \"{ctxs_list}\""
        if i < cl: contexts += "\n"
    if contexts: contexts = "\n\n" + contexts

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

    tests = "#!/bin/bash\n\n{}tests=(\n{}\n)".format(header, "\n".join(oTests)) if len(oTests) else ""

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
