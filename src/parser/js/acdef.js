#!/usr/bin/env node

"use strict";

const { md5, hasProp } = require("../../utils/toolbox.js");

module.exports = async (branches, cchains, flags, settings, S, cmdname) => {
	let ubids = S.ubids;
	let text = S.text;
	let tokens = S.lexerdata.tokens;
	let excludes = S.excludes;

	let oSets = {};
	let oDefaults = {};
	let oFiledirs = {};
	let oContexts = {};

	let oSettings = {};
	let settings_count = 0;
	let oTests = [];
	let oPlaceholders = {};
	let omd5Hashes = {};
	let acdef = "";
	let acdef_lines = [];
	let config = "";
	let defaults = "";
	let filedirs = "";
	let contexts = "";
	let has_root = false;

	// Collect all universal block flags.
	let ubflags = [];
	for (let i = 0, l = ubids.length; i < l; i++) {
		let ubid = ubids[i];
		for (let i = 0, l = flags[ubid].length; i < l; i++) {
			ubflags.push(flags[ubid][i]);
		}
	}
	let oKeywords = [oDefaults, oFiledirs, oContexts];

	// Escape '+' chars in commands.
	const rcmdname = cmdname.replace(/\+/g, "\\+");
	const r = new RegExp(`^(${rcmdname}|[-_a-zA-Z0-9]+)`);

	const re_space = /\s/;
	const re_space_cl = /;\s+/;

	const date = new Date(); // [https://stackoverflow.com/a/3313887]
	const hours = `${date.getHours()}`.padStart(2, "0");
	const minutes = `${date.getMinutes()}`.padStart(2, "0");
	const seconds = `${date.getSeconds()}`.padStart(2, "0");
	const datestring = `${date.toDateString()}`.padStart(2, "0");
	const timestamp = Math.floor(date.getTime() / 1000); // Date.now();
	const ctime = `${datestring} ${hours}:${minutes}:${seconds} (${timestamp})`;
	let header = `# DON'T EDIT FILE —— GENERATED: ${ctime}\n\n`;
	if (S.args.test) header = "";

	function tkstr(tid) {
		if (tid === -1) return "";
		// Return interpolated string for string tokens.
		if (tokens[tid].kind === "tkSTR") return tokens[tid].$;
		return text.substring(tokens[tid].start, tokens[tid].end + 1);
	}

	/**
	 * compare function: Uses builtin localeCompare to sort.
	 *
	 * @param  {string} a - Item a.
	 * @param  {string} b - Item b.
	 * @return {number} - Sort result.
	 *
	 * @resource [https://stackoverflow.com/a/50490371]
	 * @resource [http://ecma-international.org/ecma-402/1.0/#CompareStrings]
	 */
	// let lsort = (a, b) => a.localeCompare(b);

	/**
	 * compare function: Sorts alphabetically.
	 *
	 * @param  {string} a - Item a.
	 * @param  {string} b - Item b.
	 * @return {number} - Sort result.
	 *
	 * @resource [https://stackoverflow.com/a/6712058]
	 * @resource [https://stackoverflow.com/a/42478664]
	 * @resource [http://www.fileformat.info/info/charset/UTF-16/list.htm]
	 *
	 */
	// let asort = (a, b) => {
	// 	a = a.toLowerCase();
	// 	b = b.toLowerCase();

	// 	// Long form: [https://stackoverflow.com/a/9175302]
	// 	// if (a > b) return 1;
	// 	// else if (a < b) return -1;

	// 	// // Second comparison.
	// 	// if (a.length < b.length) return -1;
	// 	// else if (a.length > b.length) return 1;
	// 	// else return 0;

	// 	return a.value !== b.value ? (a.value < b.value ? -1 : 1) : 0;
	// };
	let asort = (a, b) => {
		let r = a.val !== b.val ? (a.val < b.val ? -1 : 1) : 0;
		if (r === 0 && a.single && b.single) r = a.orig < b.orig ? 1 : 0;
		return r;
	};
	let aobj = (s) => ({ val: s.toLowerCase() });

	/**
	 * compare function: Gives precedence to flags ending with '=*' else
	 *     falls back to sorting alphabetically.
	 *
	 * @param  {string} a - Item a.
	 * @param  {string} b - Item b.
	 * @return {number} - Sort result.
	 *
	 * Give multi-flags higher sorting precedence:
	 * @resource [https://stackoverflow.com/a/9604891]
	 * @resource [https://stackoverflow.com/a/24292023]
	 * @resource [http://www.javascripttutorial.net/javascript-array-sort/]
	 */
	// let sort = (a, b) => ~~b.endsWith("=*") - ~~a.endsWith("=*") || asort(a, b);
	let fsort = (a, b) => b.m - a.m || asort(a, b);
	let fobj = (s) => {
		let o = { val: s.toLowerCase(), m: ~~s.endsWith("=*") };
		if (s[1] !== "-") {
			o.orig = s;
			o.single = true;
		}
		return o;
	};

	/**
	 * Uses map sorting to reduce redundant preprocessing on array items.
	 *
	 * @param  {array} A - The source array.
	 * @param  {function} comp - The comparator function to use.
	 * @return {array} - The resulted sorted array.
	 *
	 * @resource [https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/sort]
	 */
	let mapsort = (A, comp, comp_obj) => {
		let T = []; // Temp array.
		let R = []; // Result array.
		let l = A.length;
		for (let i = 0; i < l; i++) {
			let obj = comp_obj(A[i]);
			obj.i = i;
			T.push(obj);
		}
		T.sort(comp);
		for (let i = 0, l = T.length; i < l; i++) R[i] = A[T[i].i];
		return R;
	};

	/**
	 * Removes first command in command chain. However, when command name
	 * is not the main command in (i.e. in a test file) just remove the
	 * first command name in the chain.
	 *
	 * @param  {string} command - The command chain.
	 * @return {string} - Modified chain.
	 */
	let rm_fcmd = (chain) => chain.replace(r, "");

	let lastn = (list, offset = -1) => list[list.length + offset];
	let strfrmpts = (s, start, end) => s.substring(start, end + 1);

	function get_cmdstr(start, stop) {
		let output = [];
		const allowed_tk_types = new Set(["tkSTR", "tkDLS"]);
		for (let tid = start; tid < stop; tid++) {
			if (allowed_tk_types.has(tokens[tid].kind)) {
				if (output.length && lastn(output) === "$") {
					output[output.length - 1] = "$" + tkstr(tid);
				} else output.push(tkstr(tid));
			}
		}

		return `$(${output.join(",")})`;
	}

	function processflags(gid, chain, flags, queue_flags, recunion = false, recalias = false) {
		let unions = [];

		for (let i = 0, l = flags.length; i < l; i++) {
			let flg = flags[i];
			let tid = flg.tid;
			let assignment = tkstr(flg.assignment);
			let boolean = tkstr(flg.boolean);
			let alias = tkstr(flg.alias);
			let flag = tkstr(tid);
			let ismulti = tkstr(flg.multi);
			let union = flg.union !== -1;
			let values = flg.values;
			let kind = tokens[tid].kind;

			if (alias && !recalias) {
				processflags(gid, chain, [flg], queue_flags, false, true);
			}

			// Skip union logic on recursion.
			if (!recalias && kind !== "tkKYW" && !recunion) {
				if (union) {
					unions.push(flg);
					continue;
				} else if (unions) {
					for (let i = 0, l = unions.length; i < l; i++) {
						let uflg = unions[i];
						uflg.values = values;
						processflags(gid, chain, [uflg], queue_flags, true, false);
					}
					unions.length = 0;
				}
			}

			if (recalias) {
				oContexts[chain][`{${flag.replace(/^-*/, "")}|${alias}}`] = 1;
				flag = "-" + alias;
			}

			if (kind === "tkKYW") {
				if (values.length && flag !== "exclude") {
					let value = "";
					if (values[0].length === 1) {
						value = tkstr(values[0][0]).replace(re_space, "");
						if (flag === "context") value = value.slice(1, -1);
					} else {
						value = get_cmdstr(values[0][1] + 1, values[0][2]);
					}

					if (flag === "default") oDefaults[chain][value] = 1;
					else if (flag === "filedir") oFiledirs[chain][value] = 1;
					else if (flag === "context") oContexts[chain][value] = 1;
				}

				continue;
			}

			// Flag with values: build each flag + value.
			if (values.length) {
				// Baseflag: add multi-flag indicator?
				// Add base flag to Set (adds '--flag=' or '--flag=*').
				queue_flags[`${flag}=${ismulti ? "*" : ""}`] = 1;
				let mflag = `${flag}=${ismulti ? "" : "*"}`;
				if (hasProp(queue_flags, mflag)) delete queue_flags[mflag];

				for (let i = 0, l = values.length; i < l; i++) {
					let value = values[i];
					if (value.length === 1) {
						// Single
						queue_flags[flag + assignment + tkstr(value[0])] = 1;
					} else {
						// Command-string
						let cmdstr = get_cmdstr(value[1] + 1, value[2]);
						queue_flags[flag + assignment + cmdstr] = 1;
					}
				}
			} else {
				if (!ismulti) {
					if (boolean) queue_flags[flag + "?"] = 1;
					else if (assignment) queue_flags[flag + "="] = 1;
					else queue_flags[flag] = 1;
				} else {
					queue_flags[flag + "=*"] = 1;
					queue_flags[flag + "="] = 1;
				}
			}
		}
	}

	function populate_keywords(chain) {
		for (let i = 0, l = oKeywords.length; i < l; i++) {
			let kdict = oKeywords[i];
			if (!hasProp(kdict, chain)) kdict[chain] = {};
		}
	}

	function populate_chain_flags(gid, chain, container) {
		if (!excludes.includes(chain)) {
			processflags(gid, chain, ubflags, container);
		}

		if (!hasProp(oSets, chain)) {
			oSets[chain] = container;
		} else {
			Object.assign(oSets[chain], container);
		}
	}

	function build_kwstr(kwtype, container) {
		let output = [];
		let chains = [];
		for (const chain in container) {
			// [https://stackoverflow.com/a/24510557]
			if (Object.getOwnPropertyNames(container[chain]).length) {
				chains.push(chain);
			}
		}
		chains = mapsort(chains, asort, aobj);
		let cl = chains.length - 1;
		for (let i = 0, l = chains.length; i < l; i++) {
			let chain = chains[i];
			let values = Object.getOwnPropertyNames(container[chain]);
			let value = kwtype !== "context" ? lastn(values) : '"' + values.join(";") + '"';
			output.push(`${rm_fcmd(chain)} ${kwtype} ${value}`);
			if (i < cl) output.push("\n");
		}

		return output.length ? "\n\n" + output.join("") : "";
	}

	function make_chains(ccids) {
		let slots = [];
		let chains = [];
		let groups = [];
		let grouping = false;

		for (let i = 0, l = ccids.length; i < l; i++) {
			let cid = ccids[i];

			if (cid === -1) grouping = !grouping;

			if (!grouping && cid !== -1) {
				slots.push(tkstr(cid));
			} else if (grouping) {
				if (cid === -1) {
					slots.push("?");
					groups.push([]);
				} else lastn(groups).push(tkstr(cid));
			}
		}

		let tstr = slots.join(".");

		for (let i = 0, l = groups.length; i < l; i++) {
			let group = groups[i];

			if (!chains.length) {
				for (let i = 0, l = group.length; i < l; i++) {
					let command = group[i];
					chains.push(tstr.replace("?", command));
				}
			} else {
				let tmp_cmds = [];
				for (let i = 0, l = chains.length; i < l; i++) {
					let chain = chains[i];
					for (let i = 0, l = group.length; i < l; i++) {
						let command = group[i];
						tmp_cmds.push(chain.replace("?", command));
					}
				}
				chains = tmp_cmds;
			}
		}

		if (!groups.length) chains.push(tstr);

		return chains;
	}

	// Start building acmap contents. -------------------------------------------

	for (let i = 0, l = cchains.length; i < l; i++) {
		let group = cchains[i];

		for (let j = 0, l = group.length; j < l; j++) {
			let ccids = group[j];

			for (let k = 0, l = make_chains(ccids).length; k < l; k++) {
				let chain = make_chains(ccids)[k];

				if (chain === "*") continue;

				let container = {};
				populate_keywords(chain);
				processflags(i, chain, flags[i] || [], container);
				populate_chain_flags(i, chain, container);

				// Create missing parent chains.
				let commands = chain.split(/(?<!\\)\./);
				commands.pop(); // Remove last command (already made).
				for (let _ = commands.length - 1; _ > -1; _--) {
					let rchain = commands.join("."); // Remainder chain.

					populate_keywords(rchain);
					if (!hasProp(oSets, rchain)) {
						populate_chain_flags(i, rchain, {});
					}

					commands.pop(); // Remove last command.
				}
			}
		}
	}

	defaults = build_kwstr("default", oDefaults);
	filedirs = build_kwstr("filedir", oFiledirs);
	contexts = build_kwstr("context", oContexts);

	// Populate settings object.
	for (let i = 0, l = settings.length; i < l; i++) {
		let setting = settings[i];
		let name = tkstr(setting[0]).slice(1);
		if (name === "test") oTests.push(tkstr(setting[2]).replace(re_space_cl, ";"));
		else oSettings[name] = setting.length > 1 ? tkstr(setting[2]) : "";
	}

	// Build settings contents.
	settings_count = Object.keys(oSettings).length;
	settings_count -= 1;
	for (const setting in oSettings) {
		config += `@${setting} = ${oSettings[setting]}`;
		if (settings_count) config += "\n";
		settings_count -= 1;
	}

	let placehold = hasProp(oSettings, "placehold") && oSettings.placehold === "true";
	for (const key in oSets) {
		let flags = mapsort(Object.keys(oSets[key]), fsort, fobj).join("|");
		if (!flags.length) flags = "--";

		// Note: Placehold long flag sets to reduce the file's chars.
		// When flag set is needed its placeholder file can be read.
		if (placehold && flags.length >= 100) {
			if (!hasProp(omd5Hashes, flags)) {
				// [https://stackoverflow.com/a/65613163]
				let md5hash = md5(flags).substr(26);
				oPlaceholders[md5hash] = flags;
				omd5Hashes[flags] = md5hash;
				flags = "--p#" + md5hash;
			} else flags = "--p#" + omd5Hashes[flags];
		}

		let row = `${rm_fcmd(key)} ${flags}`;

		// Remove multiple ' --' command chains. Shouldn't be the
		// case but happens when multiple main commands are used.
		if (row === " --" && !has_root) has_root = true;
		else if (row === " --" && has_root) continue;

		acdef_lines.push(row);
	}

	// If contents exist, add newline after header.
	let sheader = header.replace(/\n$/, "");
	let acdef_contents = mapsort(acdef_lines, asort, aobj).join("\n");
	acdef = acdef_contents ? header + acdef_contents : sheader;
	config = config ? header + config : sheader;

	let tests = oTests.length ? `#!/bin/bash\n\n${header}tests=(\n${oTests.join("\n")}\n)` : "";

	return [
		acdef,
		config,
		defaults,
		filedirs,
		contexts,
		"", // formatted
		oPlaceholders,
		tests
	];
};
