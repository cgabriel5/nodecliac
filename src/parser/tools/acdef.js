"use strict";

const flatry = require("flatry");
const node = require("../helpers/nodes.js");
const { md5, hasProp, write } = require("../../utils/toolbox.js");

/**
 * Generate .acdef, .config.acdef file contents.
 *
 * @param  {object} S - State object.
 * @param  {string} cmdname - Name of <command>.acdef being parsed.
 * @return {object} - Object containing acdef, config, and keywords contents.
 */
module.exports = async (S, cmdname) => {
	let oSets = {};
	let oGroups = {};
	let oDefaults = {};
	let oFiledirs = {};
	let oContexts = {};
	let oSettings = {};
	let settings_count = 0;
	let oPlaceholders = {};
	let omd5Hashes = {};
	let count = 0;
	let acdef = "";
	let acdef_lines = [];
	let config = "";
	let defaults = "";
	let filedirs = "";
	let contexts = "";
	let has_root = false;

	// Escape '+' chars in commands.
	const rcmdname = cmdname.replace(/\+/g, "\\+");
	const r = new RegExp(`^(${rcmdname}|[-_a-zA-Z0-9]+)`);

	const date = new Date();
	const hours = date.getHours();
	const minutes = date.getMinutes();
	const seconds = date.getSeconds();
	const datestring = date.toDateString();
	const timestamp = Math.floor(date.getTime() / 1000); // Date.now();
	const ctime = `${datestring} ${hours}:${minutes}:${seconds} (${timestamp})`;
	let header = `# DON'T EDIT FILE —— GENERATED: ${ctime}\n\n`;
	if (S.args.test) header = "";

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
	let asort = (a, b) => (a.val !== b.val ? (a.val < b.val ? -1 : 1) : 0);
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
	let fobj = (s) => ({ val: s.toLowerCase(), m: ~~s.endsWith("=*") });

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

	// Group commands with their flags.

	let last = "";
	let rN = {}; // Reference node.
	let dN = []; // Delimited flag nodes.
	let xN = S.tables.tree.nodes;
	let wildcard = false;
	let wc_flg = [];
	let wc_exc = new Set();
	const ftypes = new Set(["FLAG", "OPTION"]);
	const types = new Set(["SETTING", "COMMAND", "FLAG", "OPTION"]);

	// Contain missing parent command chains in their own group.
	oGroups[-1] = { commands: [], flags: [] };

	for (let i = 0, l = xN.length; i < l; i++) {
		let N = xN[i];
		let type = N.node;

		if (!types.has(type)) continue;

		// Check whether new group must be started.
		if (last) {
			if (last === "COMMAND") {
				if (type === "COMMAND" && !rN.delimiter.value) count++;
			} else if (ftypes.has(last)) {
				if (!ftypes.has(type)) count++;
			}

			last = "";
		}

		switch (type) {
			case "COMMAND": {
				// Handle wildcard node.
				if (N.command.value === "*") {
					wildcard = true;
					continue;
				} else wildcard = false;

				// Store command in current group.
				if (!oGroups[count]) {
					oGroups[count] = { commands: [N], flags: [] };
				} else oGroups[count].commands.push(N);

				const cval = N.command.value;
				if (!hasProp(oSets, cval)) {
					oSets[cval] = new Set();

					// Create missing parent chains.
					let commands = cval.split(/(?<!\\)\./);
					commands.pop(); // Remove last command (already made).
					for (let i = commands.length - 1; i > -1; i--) {
						let rchain = commands.join("."); // Remainder chain.
						if (!hasProp(oSets, rchain)) {
							let tN = node(S, "COMMAND");
							tN.command.value = rchain;
							oGroups[-1].commands.push(tN);
							oSets[rchain] = new Set();
						}
						commands.pop(); // Remove last command.
					}
				}

				last = type;
				rN = N; // Store reference to node.

				break;
			}

			case "FLAG":
				let keyword = N.keyword.value;

				// Handle wildcard flags.
				if (wildcard) {
					if (keyword === "exclude") {
						wc_exc.add(N.value.value.slice(1, -1));
					} else wc_flg.push(N);
					continue;
				}

				// Add values/arguments to delimited flags.
				if (N.delimiter.value) dN.push(N);
				// Skip/ignore keywords.
				else if (!keyword) {
					let args = N.args;
					let value = N.value.value;
					for (let i = 0, l = dN.length; i < l; i++) {
						let tN = dN[i];
						tN.args = args;
						tN.value.value = value;
					}
					dN.length = 0;
				}

				oGroups[count].flags.push(N); // Store command in current group.
				last = type;

				break;

			case "OPTION": {
				// Add value to last flag in group.
				let { flags: fxN } = oGroups[count];
				fxN[fxN.length - 1].args.push(N.value.value);
				last = type;

				break;
			}

			case "SETTING": {
				let name = N.name.value;
				if (name !== "test") {
					if (!hasProp(oSettings, name)) settings_count++;
					oSettings[name] = N.value.value;
				}

				break;
			}
		}
	}

	// Populate Sets.

	/**
	 * Add flags, keywords to respective containers.
	 *
	 * @param  {array} fxN - The flag nodes.
	 * @param  {set} queue_defs - The defaults container.
	 * @param  {set} queue_fdir - The filedirs container.
	 * @param  {set} queue_ctxs - The contexts container.
	 * @param  {set} queue_flags - The flags container.
	 * @return {undefined} - Nothing is returned.
	 */
	let queues = (fxN, queue_defs, queue_fdir, queue_ctxs, queue_flags) => {
		for (let i = 0, l = fxN.length; i < l; i++) {
			let fN = fxN[i];
			let { args } = fN;
			let keyword = fN.keyword.value;

			// If flag is a default/keyword store it.
			if (keyword) {
				let value = fN.value.value;
				if (keyword === "default") queue_defs.add(value);
				else if (keyword === "filedir") queue_fdir.add(value);
				else if (keyword == "context") {
					queue_ctxs.add(value.slice(1, -1));
				}
				continue; // defaults don't need to be added to Sets.
			}

			const aval = fN.assignment.value;
			const bval = fN.boolean.value;
			const flag = `${fN.hyphens.value}${fN.name.value}`;
			const ismulti = fN.multi.value !== "";

			// Flag with values: build each flag + value.
			if (args.length) {
				// Baseflag: add multi-flag indicator?
				// Add base flag to Set (adds '--flag=' or '--flag=*').
				queue_flags.add(`${flag}=${ismulti ? "*" : ""}`);
				queue_flags.delete(`${flag}=${ismulti ? "" : "*"}`);

				args.forEach((arg) => queue_flags.add(flag + aval + arg));
			} else {
				if (!ismulti) {
					if (bval) queue_flags.add(flag + "?");
					else if (aval) queue_flags.add(flag + "=");
					else queue_flags.add(flag);
				} else {
					queue_flags.add(flag + "=*");
					queue_flags.add(flag + "=");
				}
			}
		}
	};

	for (let i in oGroups) {
		if (!hasProp(oGroups, i)) continue;

		let { commands: cxN, flags: fxN } = oGroups[i];
		let queue_defs = new Set();
		let queue_fdir = new Set();
		let queue_ctxs = new Set();
		let queue_flags = new Set();

		queues(fxN, queue_defs, queue_fdir, queue_ctxs, queue_flags);

		let a = [wc_flg, queue_defs, queue_fdir, queue_ctxs, queue_flags];
		for (let i = 0, l = cxN.length; i < l; i++) {
			let value = cxN[i].command.value;

			// Add wildcard flags.
			if (wc_flg.length && !wc_exc.has(value)) queues.apply(null, a);

			for (let item of queue_flags) oSets[value].add(item);
			for (let item of queue_defs) oDefaults[value] = item;
			for (let item of queue_fdir) oFiledirs[value] = item;
			for (let item of queue_ctxs) {
				if (hasProp(oContexts, value)) oContexts[value] += ";" + item;
				else oContexts[value] = item;
			}
		}
	}

	// Generate acdef.

	let placehold = oSettings["placehold"] && oSettings["placehold"] === "true";
	for (let command in oSets) {
		if (command && hasProp(oSets, command)) {
			let set = oSets[command];
			let flags = "--";

			// If Set has items then it has flags so convert to an array.
			// [https://stackoverflow.com/a/47243199]
			// [https://stackoverflow.com/a/21194765]
			if (set.size) flags = mapsort([...set], fsort, fobj).join("|");

			// Note: Placehold long flag sets to reduce the file's chars.
			// When flag set is needed its placeholder file can be read.
			if (placehold && flags.length >= 100) {
				if (!hasProp(omd5Hashes, flags)) {
					let md5hash = md5(flags).substr(26);
					oPlaceholders[md5hash] = flags;
					omd5Hashes[flags] = md5hash;
					flags = "--p#" + md5hash;
				} else flags = "--p#" + omd5Hashes[flags];
			}

			let row = `${rm_fcmd(command)} ${flags}`;

			// Remove multiple ' --' command chains. Shouldn't be the
			// case but happens when multiple main commands are used.
			if (row === " --" && !has_root) has_root = true;
			else if (row === " --" && has_root) continue;

			acdef_lines.push(row);
		}
	}

	// Build defaults contents.
	let defs = mapsort(Object.keys(oDefaults), asort, aobj);
	let dl = defs.length - 1;
	defs.forEach((c, i) => {
		defaults += `${rm_fcmd(c)} default ${oDefaults[c]}`;
		if (i < dl) defaults += "\n";
	});
	if (defaults) defaults = "\n\n" + defaults;

	// Build filedirs contents.
	let fdirs = mapsort(Object.keys(oFiledirs), asort, aobj);
	let fl = fdirs.length - 1;
	fdirs.forEach((c, i) => {
		filedirs += `${rm_fcmd(c)} filedir ${oFiledirs[c]}`;
		if (i < fl) filedirs += "\n";
	});
	if (filedirs) filedirs = "\n\n" + filedirs;

	// Build contexts contents.
	var ctxlist = [];
	for (let context in oContexts) ctxlist.push(context);
	let ctxs = mapsort(Object.keys(oContexts), asort, aobj);
	let cl = ctxs.length - 1;
	ctxs.forEach((c, i) => {
		contexts += rm_fcmd(c) + ' context "' + oContexts[c] + '"';
		if (i < cl) contexts += "\n";
	});
	if (contexts !== "") contexts = "\n\n" + contexts;

	// Build settings contents.
	settings_count--;
	for (let setting in oSettings) {
		if (hasProp(oSettings, setting)) {
			config += `@${setting} = ${oSettings[setting]}`;
			if (settings_count) config += "\n";
			settings_count--;
		}
	}

	// If contents exist, add newline after header.
	let sheader = header.replace(/\n$/, "");
	let acdef_contents = mapsort(acdef_lines, asort, aobj).join("\n");
	acdef = acdef_contents ? header + acdef_contents : sheader;
	config = config ? header + config : sheader;

	let tests = S.tests.length
		? `#!/bin/bash\n\n${header}tests=(\n${S.tests.join("\n")}\n)`
		: "";

	return Promise.resolve({
		acdef,
		config,
		keywords: defaults,
		filedirs,
		contexts,
		placeholders: oPlaceholders,
		tests
	});
};
