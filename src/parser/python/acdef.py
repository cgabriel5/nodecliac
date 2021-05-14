#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re
import functools

def acdef(branches, cchains, flags, S):

    tokens = S["tokens"]
    text = S["text"]

    def tkstr(tid):
        if tid == -1: return ""
        return text[tokens[tid]["start"]:tokens[tid]["end"] + 1]

    oSets = {}
    oFlags = {}

    NOFLAGS = {"--": 1}

    rcmdname = "a"
    r = re.compile(f"^({rcmdname}|[-_a-zA-Z0-9]+)")

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

    for i, group in enumerate(cchains):

        if i in flags:

            queue_flags = {}

            for flg in flags[i]:

                tid = flg["tid"]
                assignment = tkstr(flg["assignment"])
                boolean = tkstr(flg["boolean"])
                flag = tkstr(tid)
                ismulti = tkstr(flg["multi"])
                values = flg["values"]

                if flag in ("default"):
                    continue

                # Flag with values: build each flag + value.
                if values:
                    # Baseflag: add multi-flag indicator?
                    # Add base flag to Set (adds '--flag=' or '--flag=*').
                    queue_flags[f"{flag}={'*' if ismulti else ''}"] = 1
                    mflag = f"{flag}={'' if ismulti else '*'}"
                    if mflag in queue_flags:
                        del queue_flags[mflag]

                    for value in values:
                        if len(value) == 1: # Single
                            queue_flags[flag + assignment + tkstr(value[0])] = 1
                        else: # Command-string
                            strs = []
                            for tid in range(value[1]+1, value[2]):
                                if S["tokens"][tid]["kind"] in ("tkSTR", "tkDLS"):
                                    if strs and strs[-1] == "$":
                                        strs[-1] = "$" + tkstr(tid)
                                    else:
                                        strs.append(tkstr(tid))

                            queue_flags[flag + assignment + "$(" + ",".join(strs) + ")"] = 1

                else:
                    if not ismulti:
                        if boolean: queue_flags[flag + "?"] = 1
                        elif assignment: queue_flags[flag + "="] = 1
                        else: queue_flags[flag] = 1
                    else:
                        queue_flags[flag + "=*"] = 1
                        queue_flags[flag + "="] = 1

            oFlags[i] = queue_flags

        else:
            oFlags[i] = NOFLAGS

        for chain in group:

            chains = []
            slots = []
            expand = False
            expandables = []
            indices = []

            for j, command in enumerate(chain):

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
                # Create missing parent chains.
                commands = re.split(r'(?<!\\)\.', chain)
                commands.pop() # Remove last command (already made).
                for _ in range(len(commands) - 1, -1, -1):
                    rchain = ".".join(commands) # Remainder chain.

                    if rchain not in oSets:
                        oSets[rchain] = NOFLAGS
                    commands.pop() # Remove last command.

                oSets[chain] = oFlags[i]

    acdef_lines = []
    for key in oSets:
        flags = "|".join(mapsort(list(oSets[key].keys()), fsort, fobj))

        row = f"{rm_fcmd(key)} {flags}"
        acdef_lines.append(row)

    acdef_contents = "\n".join(mapsort(acdef_lines, asort, aobj))
    print(acdef_contents)
