"use strict";

const { md5, hasProp } = require("../../utils/toolbox.js");

/**
 * Generate .acdef, .config.acdef file contents.
 *
 * @param  {object} S - State object.
 * @param  {string} cmdname - Name of <command>.acdef being parsed.
 * @return {object} - Object containing acdef, config, and keywords contents.
 */
module.exports = (S, cmdname) => {
	let oSets = {};
	let oGroups = {};
	let oDefaults = {};
	let oSettings = {};
	let oPlaceholders = {};
	let omd5Hashes = {};
	let count = 0;
	let acdef = "";
	let acdef_lines = [];
	let config = "";
	let defaults = "";
	let has_root = false;

	// Escape '+' chars in commands.
	const rcmdname = cmdname.replace(/(\+)/g, "\\$1");
	const r = new RegExp(`^(${rcmdname}|[-_a-zA-Z0-9]+)`);

	const date = new Date();
	const timestamp = date.getTime(); // Date.now();
	const ctime = `${date}(${timestamp})`;
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
	let lsort = (a, b) => a.localeCompare(b);

	/**
	 * compare function: Sorts alphabetically.
	 *
	 * @param  {string} a - Item a.
	 * @param  {string} b - Item b.
	 * @return {number} - Sort result.
	 *
	 * @resource [https://stackoverflow.com/a/6712058]
	 * @resource [https://stackoverflow.com/a/42478664]
	 */
	let asort = (a, b) => {
		a = a.toLowerCase();
		b = b.toLowerCase();
		return a !== b ? (a < b ? -1 : 1) : 0;
	};

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
	let sort = (a, b) => ~~b.endsWith("=*") - ~~a.endsWith("=*") || asort(a, b);

	/**
	 * Add base flag to Set (adds '--flag=' or '--flag=*').
	 *
	 * @param  {object} fN - Flag Node object.
	 * @param  {array} cxN - List of commands to attach flags to.
	 * @param  {string} flag - The flag (hyphen(s) + flag name).
	 * @return {undefined} - Nothing is returned.
	 */
	let baseflag = (fN, cxN, flag) => {
		const ismulti = fN.multi.value;
		const add = `${flag}=${ismulti ? "*" : ""}`;
		const del = `${flag}=${ismulti ? "" : "*"}`;
		cxN.forEach(N => oSets[N.command.value].add(add).delete(del));
	};

	/**
	 * Removes first command in command chain. However, when command name
	 * is not the main command in (i.e. in a test file) just remove the
	 * first command name in the chain.
	 *
	 * @param  {string} command - The command chain.
	 * @return {string} - Modified chain.
	 */
	let rm_fcmd = chain => chain.replace(r, "");

	// Get needed Nodes.

	let xN = [];
	const types = ["SETTING", "COMMAND", "FLAG", "OPTION"];
	S.tables.tree.nodes.forEach(N => {
		let type = N.node;
		if (types.includes(type)) {
			if (type !== "SETTING") xN.push(N);
			else oSettings[N.name.value] = N.value.value;
		}
	});

	// Group commands with their flags.

	for (let i = 0, l = xN.length; i < l; i++) {
		let N = xN[i];
		let nN = xN[i + 1] || {};
		let type = N.node;

		if (!types.includes(type)) continue;

		if (type === "COMMAND") {
			// Store command in current group.
			if (!oGroups[count]) oGroups[count] = { commands: [N], flags: [] };
			else oGroups[count].commands.push(N);

			const cval = N.command.value;
			if (!hasProp(oSets, cval)) {
				oSets[cval] = new Set();

				// Create missing parent chains.
				let commands = cval.split(/(?<!\\)\./);
				commands.pop(); // Remove last command (already made).
				for (let i = commands.length - 1; i > -1; i--) {
					let rchain = commands.join("."); // Remainder chain.
					if (!hasProp(oSets, rchain)) oSets[rchain] = new Set();
					commands.pop(); // Remove last command.
				}
			}

			// Increment count: start new group.
			if (nN && nN.node === "COMMAND" && !N.delimiter.value) count++;
		} else if (type === "FLAG") {
			oGroups[count].flags.push(N); // Store command in current group.

			// Increment count: start new group.
			if (nN && !["FLAG", "OPTION"].includes(nN.node)) count++;
		} else if (type === "OPTION") {
			// Add value to last flag in group.
			let { flags: fxN } = oGroups[count];
			fxN[fxN.length - 1].args.push(N.value.value);

			// Increment count: start new group.
			if (nN && !["FLAG", "OPTION"].includes(nN.node)) count++;
		} else if (type === "SETTING") {
			oSettings[N.name.value] = N.value.value;
		}
	}

	// Populate Sets.

	for (let i in oGroups) {
		if (!hasProp(oGroups, i)) continue;

		let { commands: cxN, flags: fxN } = oGroups[i];
		for (let i = 0, l = fxN.length; i < l; i++) {
			let fN = fxN[i];
			let { args } = fN;
			const fval = fN.value.value;
			const aval = fN.assignment.value;
			const bval = fN.boolean.value;
			const flag = `${fN.hyphens.value}${fN.name.value}`;

			// If flag is a default/keyword store it.
			if (fN.keyword.value) {
				cxN.forEach(N => (oDefaults[N.command.value] = fval));
				continue; // defaults don't need to be added to Sets.
			}

			// Flag with values: build each flag + value.
			if (args.length) {
				args.forEach(arg => {
					baseflag(fN, cxN, flag); // add multi-flag indicator?

					cxN.forEach(N => {
						let add = `${flag}${aval || ""}${arg || ""}`;
						oSets[N.command.value].add(add);
					});
				});
			} else {
				// Flag is a boolean...
				const val = bval ? "?" : aval ? "=" : "";
				cxN.forEach(N => oSets[N.command.value].add(`${flag}${val}`));
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
			if (set.size) flags = [...set].sort(sort).join("|");

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
	let dkeys = Object.keys(oDefaults).sort(asort);
	dkeys.forEach(c => (defaults += `${rm_fcmd(c)} default ${oDefaults[c]}\n`));
	if (defaults) defaults = "\n\n" + defaults;

	// Build settings contents.
	for (let setting in oSettings) {
		if (hasProp(oSettings, setting)) {
			config += `@${setting} = ${oSettings[setting]}\n`;
		}
	}

	acdef = header + acdef_lines.sort(asort).join("\n");
	config = header + config;

	return {
		acdef: acdef.replace(/\s*$/g, ""),
		config: config.replace(/\s*$/g, ""),
		keywords: defaults.replace(/\s*$/g, ""),
		placeholders: oPlaceholders
	};
};
