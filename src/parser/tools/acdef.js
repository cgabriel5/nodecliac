"use strict";

const { md5, hasOwnProperty } = require("../../utils/toolbox.js");

/**
 * Generate .acdef, .config.acdef file contents from parse tree ob nodes.
 *
 * @param  {object} S - Main loop state object.
 * @param  {string} cmdname - Name of <command>.acdef being parsed.
 * @return {object} - Object containing acdef, config, and keywords contents.
 */
module.exports = (S, cmdname) => {
	let counter = 0;
	let nodes = [];
	let ACDEF = [];
	let SETS = {};
	let BATCHES = {};
	let DEFAULTS = {};
	let SETTINGS = {};
	let PLACEHOLDERS = {};
	let TREE = S.tables.tree;
	let memtable = {}; // Cache md5 hash to their respective flags string.
	let has_root = false;

	// Note: Properly escape '+' characters for commands like 'g++'.
	let rcmdname = cmdname.replace(/(\+)/g, "\\$1");
	// RegExp to match main command/first command in chain to remove.
	let r = new RegExp(`^(${rcmdname}|[-_a-zA-Z0-9]+)`);

	// .acdef/.config.acdef file header.
	const date = new Date();
	const timestamp = Date.now();
	let header = `# DON'T EDIT FILE —— GENERATED: ${date}(${timestamp})\n\n`;
	if (S.args.test) header = ""; // Reset header when testing.

	/**
	 * Add base flag to Set (adds '--flag=' or '--flag=*' to Set).
	 *
	 * @param  {object} fN - The flag object Node.
	 * @param  {array} COMMANDS - The list of commands to attach flags to.
	 * @param  {string} flag - The flag (hyphens + flag name).
	 * @return {undefined} - Nothing is returned.
	 */
	let baseflag = (fN, COMMANDS, flag) => {
		let ismulti = fN.multi.value; // Check if flag is a multi-flag.

		COMMANDS.forEach(N => {
			// Add flag + value to Set.
			SETS[N.command.value]
				.add(`${flag}=${ismulti ? "*" : ""}`)
				.delete(`${flag}=${ismulti ? "" : "*"}`);
		});
	};

	/**
	 * Sort function.
	 *
	 * @param  {string} a - Item a.
	 * @param  {string} b - Item b.
	 * @return {number} - The sort number result.
	 *
	 * Give multi-flags higher sorting precedence:
	 * @resource [https://stackoverflow.com/a/9604891]
	 * @resource [https://stackoverflow.com/a/24292023]
	 * @resource [http://www.javascripttutorial.net/javascript-array-sort/]
	 */
	let sorter = (a, b) => {
		return ~~b.endsWith("=*") - ~~a.endsWith("=*") || a.localeCompare(b);
	};

	/**
	 * Sort function.
	 *
	 * @param  {string} a - Item a.
	 * @param  {string} b - Item b.
	 * @return {number} - The sort number result.
	 */
	let aplhasort = (a, b) => a.localeCompare(b);

	// 1) Filter out unnecessary Nodes. ========================================

	TREE.nodes.forEach(N => {
		let type = N.node;

		if (["COMMAND", "FLAG", "OPTION", "SETTING"].includes(type)) {
			if (type !== "SETTING") nodes.push(N);
			else SETTINGS[N.name.value] = N.value.value; // Store setting/value.
		}
	});

	// 2) Batch commands with their flags. =====================================

	for (let i = 0, l = nodes.length; i < l; i++) {
		let N = nodes[i];
		let nN = nodes[i + 1] || {};
		let type = N.node;
		// let ntype = nN.node;

		if (type === "COMMAND") {
			// Store command into current batch.
			if (!BATCHES[counter]) {
				BATCHES[counter] = { commands: [N], flags: [] };
			} else BATCHES[counter].commands.push(N);

			const cvalue = N.command.value;

			// Add command to SETS if not already.
			if (!hasOwnProperty(SETS, cvalue)) {
				SETS[cvalue] = new Set();

				// Note: Create any missing parent chains. =====================

				let commands = cvalue.split(/(?<!\\)\./);
				commands.pop(); // Remove last command as it was already made.

				// For remaining commands, create Set if not already.
				for (let i = commands.length - 1; i > -1; i--) {
					let rchain = commands.join("."); // Remainder chain.

					if (!hasOwnProperty(SETS, rchain)) SETS[rchain] = new Set();

					commands.pop(); // Finally, remove the last element.
				}

				// ===========================================================
			}

			// Increment counter to start another batch.
			if (nN && nN.node === "COMMAND" && !N.delimiter.value) {
				counter++;
			}
		} else if (type === "FLAG") {
			BATCHES[counter].flags.push(N); // Store command in current batch.

			// Increment counter to start another batch.
			if (nN && !["FLAG", "OPTION"].includes(nN.node)) counter++;
		} else if (type === "OPTION") {
			// Add the value to last flag in batch.
			let FLAGS = BATCHES[counter].flags;
			FLAGS[FLAGS.length - 1].args.push(N.value.value);
		}
	}

	// 3) Populate Sets SETS. ==================================================

	for (let i in BATCHES) {
		if (!hasOwnProperty(BATCHES, i)) continue;

		let BATCH = BATCHES[i];
		let { commands: COMMANDS, flags: FLAGS } = BATCH; // Get commands/flags.

		for (let i = 0, l = FLAGS.length; i < l; i++) {
			let fN = FLAGS[i];
			let ARGS = fN.args; // Get flag arguments.
			// Build flag (hyphens + flag name).
			let flag = `${fN.hyphens.value}${fN.name.value}`;

			// Check if flag is actually a default/keyword and store it.
			if (fN.keyword.value) {
				COMMANDS.forEach(N => {
					DEFAULTS[N.command.value] = fN.value.value;
				});

				continue; // Note: Since it's a default it doesn't need to be
				// added to the SETS so stop iteration here.
			}

			// If the flag has any values build each flag + value.
			if (ARGS.length) {
				ARGS.forEach(ARG => {
					// Determine whether to add multi-flag indicator.
					baseflag(fN, COMMANDS, flag);

					// Add flag + value to Set.
					COMMANDS.forEach(N => {
						SETS[N.command.value].add(
							`${flag}${fN.assignment.value || ""}${ARG || ""}`
						);
					});
				});
			}
			// If flag does not contain any values...
			else {
				// If flag is a boolean...
				COMMANDS.forEach(N => {
					const cvalue = N.command.value;
					const bvalue = fN.boolean.value;
					const avalue = fN.assignment.value;

					SETS[cvalue].add(
						`${flag}${bvalue ? "?" : avalue ? "=" : ""}`
					);
				});
			}
		}
	}

	// Check if `placehold` flag was provided.
	let PLACEHOLD = SETTINGS["placehold"];
	PLACEHOLD = PLACEHOLD && PLACEHOLD === "true";

	// 4) Generate final ACDEF before sorting. =================================

	for (let command in SETS) {
		if (command && hasOwnProperty(SETS, command)) {
			let SET = SETS[command]; // Get Set object.
			let flags = "--";

			// If Set has items then it has flags so convert to an array.
			// [https://stackoverflow.com/a/47243199]
			// [https://stackoverflow.com/a/21194765]
			if (SET.size) flags = [...SET].sort(sorter).join("|");

			// Note: Place hold extremely long flag set strings. This is
			// done to allow faster acdef read times by reducing the file's
			// characters. If the flagset is later needed the specific place
			// holder file can then be read.
			if (PLACEHOLD && flags.length >= 100) {
				// Memoize hashes to prevent re-hashing same flag strings.
				if (!hasOwnProperty(memtable, flags)) {
					let md5hash = md5(flags).substr(26); // md5 hash of flags string.
					PLACEHOLDERS[md5hash] = flags; // Store flags in object.
					memtable[flags] = md5hash;

					flags = "--p#" + md5hash; // Reset flags string to md5hash.
				} else flags = "--p#" + memtable[flags];
			}

			// Remove the main command from the command chain. However,
			// when the command name is not the main command in (i.e.
			// when running on a test file) just remove the first command
			// name in the chain.
			let row = `${command.replace(r, "")} ${flags}`;

			// Remove multiple ' --' command chains. This will happen for
			// test files with multiple main commands.
			if (row === " --" && !has_root) has_root = true;
			else if (row === " --" && has_root) continue;

			ACDEF.push(row);
		}
	}

	ACDEF = header + ACDEF.sort(aplhasort).join("\n"); // Final acdef string.

	// 5) Build defaults list. =================================================

	let defs = [];
	Object.keys(DEFAULTS)
		.sort(aplhasort)
		.forEach(command => {
			defs.push(`${command.replace(r, "")} default ${DEFAULTS[command]}`);
		});
	defs = defs.length ? `\n\n${defs.join("\n")}` : "";

	// Build settings contents string.
	let CONFIG = header;
	for (let setting in SETTINGS) {
		if (hasOwnProperty(SETTINGS, setting)) {
			CONFIG += `@${setting} = ${SETTINGS[setting]}\n`;
		}
	}

	// 6) Right trim all strings. ==============================================

	ACDEF = ACDEF.replace(/\s*$/g, "");
	CONFIG = CONFIG.replace(/\s*$/g, "");
	defs = defs.replace(/\s*$/g, "");

	return {
		acdef: ACDEF,
		config: CONFIG,
		keywords: defs,
		placeholders: PLACEHOLDERS
	};
};
