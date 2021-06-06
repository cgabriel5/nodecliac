#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re

def formatter(tokens, text, branches, cchains, flags, settings, S):

    fmt = S["args"]["fmt"]
    igc = S["args"]["igc"]
    output = []
    r = r"/^[ \t]+/g"
    alias = None

    # Indentation level multipliers.
    MXP = {
        "tkCMT": 0,
        "tkCMD": 0,
        "tkFLG": 1,
        "tkFOPT": 2,
        "tkBRC": 0,
        "tkNL": 0,
        "tkSTN": 0,
        "tkVAR": 0,
        "tkBRC_RP": 1,
        "tkBRC_LP": 2
    }

    ttypes = S["ttypes"]
    ttids = S["ttids"]
    dtids = S["dtids"]

    nl_count = 0 # Track consecutive newlines.
    scopes = [] # Track command/flag scopes.

    [ichar, iamount] = fmt;
    def indent(type_, count):
        return ichar * ((count or MXP[type_]) * iamount)

    def tkstr(tid):
        if tid == -1: return ""
        # Return interpolated string for string tokens.
        if tokens[tid]["kind"] == "tkSTR": return tokens[tid]["$"]
        return text[tokens[tid]["start"]:tokens[tid]["end"] + 1]

    def adjacenttk(tid):
        for ttid in range(tid, -1, -1):
            if tokens[ttid]["kind"] not in ("tkNL", "tkCMT"):
                return ttid
        return -1

    def adjacenttk2(tid):
        for ttid in range(tid, -1, -1):
            if tokens[ttid]["kind"] not in ("tkNL"):
                return ttid
        return -1

    def prevtk(tid):
        for ttid in range(tid, -1, -1): return ttid

    cleaned = []
    bl = len(branches)
    for i, branch in enumerate(branches):

        kind = branch[0]["kind"]
        line = branch[0]["line"]

        first_assignment = False
        scope_level = 0

        brc_lp_count = 0
        brc_cl_count = 0

        lkind = ""
        lline = -1
        if i - 1 > -1:
            lbranch = branches[i - 1]
            lkind = lbranch[0]["kind"]
            lline = lbranch[0]["line"]

        for j, leaf in enumerate(branch):
            jkind = leaf["kind"]
            jtid = leaf["tid"]
            jline = leaf["line"]

            if kind in ("tkSTN", "tkVAR"):
                if jkind == "tkTRM": continue

                pkind = ""
                pline = -1
                if jtid != 0:
                    ptk = tokens[adjacenttk2(jtid - 1)]
                    pkind = ptk["kind"]
                    pline = ptk["line"]

                if pkind:
                    dline = jline - pline
                    if jkind in ("tkASG", "tkSTR", "tkBOL", "tkAVAL"):
                        if tokens[adjacenttk2(jtid - 1)]["kind"] == "tkCMT":
                            cleaned.append("\n")
                            if dline > 1: cleaned.append("\n")
                        cleaned.append(" ")
                        cleaned.append(tkstr(leaf["tid"]))
                    else:
                        if dline == 0:
                            cleaned.append(" ")
                            cleaned.append(tkstr(leaf["tid"]))
                        elif dline == 1:
                            cleaned.append("\n")
                            cleaned.append(tkstr(leaf["tid"]))
                        else:
                            cleaned.append("\n")
                            cleaned.append("\n")
                            cleaned.append(tkstr(leaf["tid"]))
                else:
                    cleaned.append(tkstr(leaf["tid"]))

            elif kind in ("tkCMD"):

                pkind = ""
                pline = -1
                if jtid != 0:
                    ptk = tokens[adjacenttk2(jtid - 1)]
                    pkind = ptk["kind"]
                    pline = ptk["line"]

                if pkind:
                    dline = jline - pline
                    if dline == 1:
                        cleaned.append("\n")
                    elif dline > 1:
                        cleaned.append("\n")
                        cleaned.append("\n")

                        # Collapse newlines in flag scopes.
                        # if scope_level > 0: cleaned.pop()

                if (scope_level in (1, 2) or brc_lp_count == 1) and jkind in ("tkFVAL", "tkSTR", "tkDLS", "tkTBD"):
                    adjtk = tokens[adjacenttk(jtid - 1)]["kind"]

                    if adjtk != "tkBRC_LP":
                        if cleaned[-1] != " ":
                            cleaned.append(" ")

                    if jkind == "tkSTR" and adjtk == "tkDLS":
                        cleaned.pop()

                    if jkind == "tkDLS" and adjtk == "tkASG":
                        cleaned.pop()

                if jkind == "tkASG" and not first_assignment:
                    first_assignment = True
                    cleaned.append(" ")
                    cleaned.append(tkstr(leaf["tid"]))
                    cleaned.append(" ")

                elif jkind == "tkBRC_LC":
                    brc_cl_count += 1
                    cleaned.append(tkstr(leaf["tid"]))

                elif jkind == "tkBRC_RC":
                    brc_cl_count = 0
                    cleaned.append(tkstr(leaf["tid"]))

                elif jkind == "tkDCMA" and not first_assignment:
                    cleaned.append(tkstr(leaf["tid"]))
                    if not brc_cl_count: cleaned.append("\n")

                elif jkind == "tkBRC_LB":
                    cleaned.append(tkstr(leaf["tid"]))
                    scope_level = 1

                elif jkind == "tkBRC_RB":
                    scope_level = 0
                    first_assignment = False
                    # cleaned.append("\n")
                    cleaned.append(tkstr(leaf["tid"]))

                elif jkind == "tkFLG":
                    if scope_level:
                        # cleaned.append("\n")
                        cleaned.append(indent(jkind, scope_level))
                    cleaned.append(tkstr(leaf["tid"]))

                elif jkind == "tkKYW":
                    if scope_level:
                        # cleaned.append("\n")
                        cleaned.append(indent(jkind, scope_level))
                    cleaned.append(tkstr(leaf["tid"]))
                    cleaned.append(" ")

                elif jkind == "tkFOPT":
                    scope_level = 2
                    # cleaned.append("\n")
                    cleaned.append(indent(jkind, scope_level))
                    cleaned.append(tkstr(leaf["tid"]))
                    # cleaned.append(" ")

                elif jkind == "tkBRC_LP":
                    brc_lp_count += 1
                    atk = tokens[adjacenttk2(jtid - 1)]["kind"]
                    if atk not in ("tkDLS", "tkASG"):

                        scope_offset = 0
                        if atk == "tkCMT": scope_offset = 1

                        cleaned.append(indent(jkind, scope_level + scope_offset))
                    cleaned.append(tkstr(leaf["tid"]))

                elif jkind == "tkBRC_RP":
                    brc_lp_count -= 1
                    if (scope_level == 2 and not brc_lp_count and
                           branch[j - 1]["kind"] != "tkBRC_LP"):
                        # cleaned.append("\n")
                        cleaned.append(indent(jkind, scope_level - 1))
                        scope_level = 1
                    cleaned.append(tkstr(leaf["tid"]))

                elif jkind == "tkCMT":
                    # [TODO] Look forward to check for long form.
                    ptk = tokens[prevtk(leaf["tid"] - 1)]["kind"]
                    atk = tokens[adjacenttk2(jtid - 1)]["kind"]
                    if ptk == "tkNL":
                        scope_offset = 0
                        if atk == "tkASG": scope_offset = 1
                        # cleaned.append("\n")
                        cleaned.append(indent(jkind, scope_level + scope_offset))
                        cleaned.append(tkstr(leaf["tid"]))
                        # cleaned.append("\n")
                    else:
                        cleaned.append(" ")
                        cleaned.append(tkstr(leaf["tid"]))
                        # cleaned.append("\n")

                else:
                    cleaned.append(tkstr(leaf["tid"]))

            elif kind in ("tkCMT"):

                pkind = ""
                pline = -1
                if jtid != 0:
                    ptk = tokens[adjacenttk2(jtid - 1)]
                    pkind = ptk["kind"]
                    pline = ptk["line"]

                if pkind:
                    dline = jline - pline
                    if dline == 1:
                        cleaned.append("\n")
                        cleaned.append(tkstr(leaf["tid"]))
                    else:
                        cleaned.append("\n")
                        cleaned.append("\n")
                        cleaned.append(tkstr(leaf["tid"]))
                else:
                    cleaned.append(tkstr(leaf["tid"]))

            else:
                if jkind not in ("tkTRM"):
                    cleaned.append(tkstr(leaf["tid"]))

    print("--------------\n\n<" + "".join(cleaned) + ">")

    return (
        "", # acdef,
        "", # config,
        "", # defaults,
        "", # filedirs,
        "", # contexts,
        "", # "", # formatted
        "", # oPlaceholders,
        "", # tests
    )
