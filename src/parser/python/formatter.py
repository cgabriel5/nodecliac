#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re

def formatter(tokens, text, branches, cchains, flags, settings, S):

    fmt = S["args"]["fmt"]
    igc = S["args"]["igc"]

    ttypes = S["ttypes"]
    ttids = S["ttids"]
    dtids = S["dtids"]

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

    NO_NL_CMT = ("tkNL", "tkCMT")

    [ichar, iamount] = fmt;
    def indent(type_, count):
        return ichar * ((count or MXP[type_]) * iamount)

    def tkstr(tid):
        if tid == -1: return ""
        # Return interpolated string for string tokens.
        if tokens[tid]["kind"] == "tkSTR": return tokens[tid]["$"]
        return text[tokens[tid]["start"]:tokens[tid]["end"] + 1]

    def prevtoken(tid, skip=("tkNL")):
        for ttid in range(tid - 1, -1, -1):
            if tokens[ttid]["kind"] not in skip:
                return ttid
        return -1

    cleaned = []
    for branch in branches:

        parentkind = branch[0]["kind"]

        first_assignment = False
        level = 0

        brc_lp_count = 0
        group_open = False

        for j, leaf in enumerate(branch):
            tid = leaf["tid"]
            kind = leaf["kind"]
            line = leaf["line"]

            ## Settings / Variables

            if parentkind in ("tkSTN", "tkVAR"):
                if kind == "tkTRM": continue

                if tid != 0:
                    ptk = tokens[prevtoken(tid)]
                    dline = line - ptk["line"]
                    if kind in ("tkASG", "tkSTR", "tkAVAL"):
                        if ptk["kind"] == "tkCMT":
                            cleaned.append("\n")
                            if dline > 1: cleaned.append("\n")
                        cleaned.append(" ")
                    else:
                        if dline == 0:   cleaned.append(" ")
                        elif dline == 1: cleaned.append("\n")
                        else:            cleaned.append("\n\n")

                cleaned.append(tkstr(leaf["tid"]))

            ## Command chains

            elif parentkind in ("tkCMD"):

                if tid != 0:
                    ptk = tokens[prevtoken(tid)]
                    dline = line - ptk["line"]

                    if dline == 1: cleaned.append("\n")
                    elif dline > 1:
                        if not group_open:
                            cleaned.append("\n")
                            cleaned.append("\n")

                        # [TODO] Add format settings to customize formatting.
                        # For example, collapse newlines in flag scopes?
                        # if level > 0: cleaned.pop()

                # When inside an indentation level or inside parenthesis,
                # append a space before every token to space things out.
                # However, because this is being done lazily, some token
                # conditions must be skipped. The skippable cases are when
                # a '$' precedes a string (""), i.e. a '$"command"'. Or
                # when an eq-sign precedes a '$', i.e. '=$("cmd")',
                if ((level or brc_lp_count == 1) and
                    kind in ("tkFVAL", "tkSTR", "tkDLS", "tkTBD")):
                    ptk = tokens[prevtoken(tid, skip=NO_NL_CMT)]
                    pkind = ptk["kind"]

                    if (pkind != "tkBRC_LP" and cleaned[-1] != " " and not
                        ((kind == "tkSTR" and pkind == "tkDLS") or
                        (kind == "tkDLS" and pkind == "tkASG"))):
                        cleaned.append(" ")

                if kind == "tkBRC_LC":
                    group_open = True
                    cleaned.append(tkstr(leaf["tid"]))

                elif kind == "tkBRC_RC":
                    group_open = False
                    cleaned.append(tkstr(leaf["tid"]))

                elif kind == "tkDCMA" and not first_assignment:
                    cleaned.append(tkstr(leaf["tid"]))
                    # Append newline after group is cloased.
                    # if not group_open: cleaned.append("\n")

                elif kind == "tkASG" and not first_assignment:
                    first_assignment = True
                    cleaned.append(" ")
                    cleaned.append(tkstr(leaf["tid"]))
                    cleaned.append(" ")

                elif kind == "tkBRC_LB":
                    cleaned.append(tkstr(leaf["tid"]))
                    level = 1

                elif kind == "tkBRC_RB":
                    level = 0
                    first_assignment = False
                    cleaned.append(tkstr(leaf["tid"]))

                elif kind == "tkFLG":
                    if level: cleaned.append(indent(kind, level))
                    cleaned.append(tkstr(leaf["tid"]))

                elif kind == "tkKYW":
                    if level: cleaned.append(indent(kind, level))
                    cleaned.append(tkstr(leaf["tid"]))
                    cleaned.append(" ")

                elif kind == "tkFOPT":
                    level = 2
                    cleaned.append(indent(kind, level))
                    cleaned.append(tkstr(leaf["tid"]))

                elif kind == "tkBRC_LP":
                    brc_lp_count += 1
                    ptk = tokens[prevtoken(tid)]
                    pkind = ptk["kind"]
                    if pkind not in ("tkDLS", "tkASG"):
                        scope_offset = int(pkind == "tkCMT")
                        cleaned.append(indent(kind, level + scope_offset))
                    cleaned.append(tkstr(leaf["tid"]))

                elif kind == "tkBRC_RP":
                    brc_lp_count -= 1
                    if (level == 2 and not brc_lp_count and
                           branch[j - 1]["kind"] != "tkBRC_LP"):
                        cleaned.append(indent(kind, level - 1))
                        level = 1
                    cleaned.append(tkstr(leaf["tid"]))

                elif kind == "tkCMT":
                    ptk = tokens[prevtoken(leaf["tid"], skip=())]["kind"]
                    atk = tokens[prevtoken(tid)]["kind"]
                    if ptk == "tkNL":
                        scope_offset = 0
                        if atk == "tkASG": scope_offset = 1
                        cleaned.append(indent(kind, level + scope_offset))
                    else: cleaned.append(" ")
                    cleaned.append(tkstr(leaf["tid"]))

                else:
                    cleaned.append(tkstr(leaf["tid"]))

            ## Comments

            elif parentkind in ("tkCMT"):

                if tid != 0:
                    ptk = tokens[prevtoken(tid)]
                    dline = line - ptk["line"]

                    if dline == 1:
                        cleaned.append("\n")
                    else:
                        cleaned.append("\n")
                        cleaned.append("\n")
                cleaned.append(tkstr(leaf["tid"]))

            else:
                if kind not in ("tkTRM"):
                    cleaned.append(tkstr(leaf["tid"]))

    # Return empty values to maintain parity with acdef.py.

    return (
        "", # acdef,
        "", # config,
        "", # defaults,
        "", # filedirs,
        "", # contexts,
        "".join(cleaned) + "\n", # "", # formatted
        "", # oPlaceholders,
        "", # tests
    )
