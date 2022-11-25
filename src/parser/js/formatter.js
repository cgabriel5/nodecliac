#!/usr/bin/env node

"use strict";

const { md5, hasProp } = require("../../utils/toolbox.js");

let lastn = (list, offset = -1) => list[list.length + offset];
// let strfrmpts = (s, start, end) => s.substring(start, end + 1);

module.exports = async (tokens, text, branches, cchains, flags, settings, S) => {
	const fmt = S.args.fmt;
	const igc = S.args.igc;

	const ttypes = S.ttypes;
	const ttids = S.ttids;
	const dtids = S.dtids;

	// Indentation level multipliers.
	const MXP = {
		tkCMT: 0,
		tkCMD: 0,
		tkFLG: 1,
		tkFOPT: 2,
		tkBRC: 0,
		tkNL: 0,
		tkSTN: 0,
		tkVAR: 0,
		tkBRC_RP: 1,
		tkBRC_LP: 2
	};

	const NO_NL_CMT = new Set(["tkNL", "tkCMT"]);

	let [ichar, iamount] = fmt;
	function indent(type_, count) {
		return ichar.repeat(((count || MXP[type_]) * iamount))
	}

	function tkstr(tid) {
		if (tid === -1) return "";
		// Return interpolated string for string tokens.
		if (tokens[tid].kind === "tkSTR") return tokens[tid].$;
		return text.substring(tokens[tid].start, tokens[tid].end + 1);
	}

	function prevtoken(tid, skip = new Set(["tkNL"])) {
		for (let ttid = tid - 1; ttid > -1; ttid--) {
			if (!skip.has(tokens[ttid].kind)) {
				return ttid;
			}
		}
		return -1;
	}

	let cleaned = [];

	for (let i = 0, l = branches.length; i < l; i++) {
		let branch = branches[i];

		let parentkind = branch[0].kind;

		let first_assignment = false;
		let level = 0;

		let brc_lp_count = 0;
		let group_open = false;

		for (let j = 0, l = branch.length; j < l; j++) {
			let leaf = branch[j];

			let tid = leaf.tid;
			let kind = leaf.kind;
			let line = leaf.line;

			//# Settings / Variables

			if (new Set(["tkSTN", "tkVAR"]).has(parentkind)) {
				if (kind === "tkTRM") {
					cleaned.push(tkstr(leaf.tid));
					continue;
				}

				if (tid !== 0) {
					let ptk = tokens[prevtoken(tid)];
					let dline = line - ptk.line;
					if (new Set(["tkASG", "tkSTR", "tkAVAL"]).has(kind)) {
						if (ptk.kind === "tkCMT") {
							cleaned.push("\n");
							if (dline > 1) cleaned.push("\n");
						}
						cleaned.push(" ");
					} else {
						if (dline === 0) cleaned.push(" ");
						else if (dline === 1) cleaned.push("\n");
						else cleaned.push("\n\n");
					}
				}

				cleaned.push(tkstr(leaf.tid));

				//# Command chains
			} else if (new Set(["tkCMD"]).has(parentkind)) {
				if (tid !== 0) {
					let ptk = tokens[prevtoken(tid)];
					let dline = line - ptk.line;

					if (dline === 1) {
						cleaned.push("\n");
					} else if (dline > 1) {
						if (!group_open) {
							cleaned.push("\n");
							cleaned.push("\n");

							// [TODO] Add format settings to customize formatting.
							// For example, collapse newlines in flag scopes?
							// if level > 0: cleaned.pop()
						}
					}
				}

				// When inside an indentation level or inside parenthesis,
				// append a space before every token to space things out.
				// However, because this is being done lazily, some token
				// conditions must be skipped. The skippable cases are when
				// a '$' precedes a string (""), i.e. a '$"command"'. Or
				// when an eq-sign precedes a '$', i.e. '=$("cmd")',
				if ((level || brc_lp_count === 1) && ["tkFVAL", "tkSTR", "tkDLS", "tkTBD"].includes(kind)) {
					let ptk = tokens[prevtoken(tid, NO_NL_CMT)];
					let pkind = ptk.kind;

					if (
						pkind !== "tkBRC_LP" &&
						lastn(cleaned) !== " " &&
						!((kind === "tkSTR" && pkind === "tkDLS") || (kind === "tkDLS" && pkind === "tkASG"))
					) {
						cleaned.push(" ");
					}
				}

				if (kind === "tkBRC_LC") {
					group_open = true;
					cleaned.push(tkstr(leaf.tid));
				} else if (kind === "tkBRC_RC") {
					group_open = false;
					cleaned.push(tkstr(leaf.tid));
				} else if (kind === "tkDCMA" && !first_assignment) {
					cleaned.push(tkstr(leaf.tid));
					// Append newline after group is cloased.
					// if (!group_open) cleaned.push("\n")
				} else if (kind === "tkASG" && !first_assignment) {
					first_assignment = true;
					cleaned.push(" ");
					cleaned.push(tkstr(leaf.tid));
					cleaned.push(" ");
				} else if (kind === "tkBRC_LB") {
					cleaned.push(tkstr(leaf.tid));
					level = 1;
				} else if (kind === "tkBRC_RB") {
					level = 0;
					first_assignment = false;
					cleaned.push(tkstr(leaf.tid));
				} else if (kind === "tkFLG") {
					if (level) cleaned.push(indent(kind, level));
					cleaned.push(tkstr(leaf.tid));
				} else if (kind === "tkKYW") {
					if (level) cleaned.push(indent(kind, level));
					cleaned.push(tkstr(leaf.tid));
					cleaned.push(" ");
				} else if (kind === "tkFOPT") {
					level = 2;
					cleaned.push(indent(kind, level));
					cleaned.push(tkstr(leaf.tid));
				} else if (kind === "tkBRC_LP") {
					brc_lp_count += 1;
					let ptk = tokens[prevtoken(tid)];
					let pkind = ptk.kind;
					if (!["tkDLS", "tkASG"].includes(pkind)) {
						let scope_offset = (pkind === "tkCMT") | 0;
						cleaned.push(indent(kind, level + scope_offset));
					}
					cleaned.push(tkstr(leaf.tid));
				} else if (kind === "tkBRC_RP") {
					brc_lp_count -= 1;
					if (level === 2 && !brc_lp_count && branch[j - 1].kind !== "tkBRC_LP") {
						cleaned.push(indent(kind, level - 1));
						level = 1;
					}
					cleaned.push(tkstr(leaf.tid));
				} else if (kind === "tkCMT") {
					let ptk = tokens[prevtoken(leaf.tid, new Set())].kind;
					let atk = tokens[prevtoken(tid)].kind;
					if (ptk === "tkNL") {
						let scope_offset = 0;
						if (atk === "tkASG") scope_offset = 1;
						cleaned.push(indent(kind, level + scope_offset));
					} else cleaned.push(" ");
					cleaned.push(tkstr(leaf.tid));
				} else {
					cleaned.push(tkstr(leaf.tid));
				}

				//# Comments
			} else if ("tkCMT" === parentkind) {
				if (tid !== 0) {
					let ptk = tokens[prevtoken(tid)];
					let dline = line - ptk.line;

					if (dline === 1) {
						cleaned.push("\n");
					} else {
						cleaned.push("\n");
						cleaned.push("\n");
					}
				}
				cleaned.push(tkstr(leaf.tid));
			} else {
				if (!new Set(["tkTRM"]).has(kind)) {
					cleaned.push(tkstr(leaf.tid));
				}
			}
		}
	}

	// Return empty values to maintain parity with acdef.py.

	return [
		"", // acdef,
		"", // config,
		"", // defaults,
		"", // filedirs,
		"", // contexts,
		cleaned.join("") + "\n", // "", // formatted
		"", // oPlaceholders,
		"" // tests
	];
};
