"use strict";

const { md5 } = require("../../../utils/toolbox.js");

/**
 * Generate .acdef, .config.acdef file contents from parse tree ob nodes.
 *
 * @param  {object} STATE - Main loop state object.
 * @param  {string} commandname - Name of <command>.acdef being parsed.
 * @return {object} - Object containing acdef, config, and keywords contents.
 */
module.exports = (STATE, commandname) => {
	let counter = 0;
	let nodes = [];
	let ACDEF = [];
	let SETS = {};
	let BATCHES = {};
	let DEFAULTS = {};
	let SETTINGS = {};
	let PLACEHOLDERS = {};
	let TREE = STATE.tables.tree;
	let memtable = {}; // Cache md5 hash to their respective flags string.
	let has_root = false;

	// Note: Properly escape '+' characters for commands like 'g++'.
	let rcommandname = commandname.replace(/(\+)/g, "\\$1");
	// RegExp to match main command/first command in chain to remove.
	let r = new RegExp(`^(${rcommandname}|[-_a-zA-Z0-9]+)`);

	// .acdef/.config.acdef file header.
	const date = new Date();
	const timestamp = Date.now();
	let header = `# DON'T EDIT FILE —— GENERATED: ${date}(${timestamp})\n\n`;
	if (STATE.args.test) header = ""; // Reset header if testing.

	/**
	 * Add base flag to Set (adds '--flag=' or '--flag=*' to Set).
	 *
	 * @param  {object} fNODE - The flag object Node.
	 * @param  {array} COMMANDS - The list of commands to attach flags to.
	 * @param  {string} flag - The flag (hyphens + flag name).
	 * @return {undefined} - Nothing is returned.
	 */
	let baseflag = (fNODE, COMMANDS, flag) => {
		let ismulti = fNODE.multi.value; // Check if flag is a multi-flag.

		COMMANDS.forEach(NODE => {
			// Add flag + value to Set.
			SETS[NODE.command.value]
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

	TREE.nodes.forEach(NODE => {
		let type = NODE.node;

		if (["COMMAND", "FLAG", "OPTION", "SETTING"].includes(type)) {
			if (type !== "SETTING") nodes.push(NODE);
			else SETTINGS[NODE.name.value] = NODE.value.value; // Store setting/value.
		}
	});

	// 2) Batch commands with their flags. =====================================

	for (let i = 0, l = nodes.length; i < l; i++) {
		let NODE = nodes[i]; // Cache current loop char.
		let nNODE = nodes[i + 1] || {};
		let type = NODE.node;
		// let ntype = nNODE.node;

		if (type === "COMMAND") {
			// Store command into current batch.
			if (!BATCHES[counter]) {
				BATCHES[counter] = { commands: [NODE], flags: [] };
			} else BATCHES[counter].commands.push(NODE);

			const cvalue = NODE.command.value;

			// Add command to SETS if not already.
			if (!Object.prototype.hasOwnProperty.call(SETS, cvalue)) {
				SETS[cvalue] = new Set();

				// Note: Create any missing parent chains. =====================

				let commands = cvalue.split(/(?<!\\)\./);
				commands.pop(); // Remove last command as it was already made.

				// For remaining commands, create Set if not already.
				for (let i = commands.length - 1; i > -1; i--) {
					let rchain = commands.join("."); // Remainder chain.

					if (!Object.prototype.hasOwnProperty.call(SETS, rchain)) {
						SETS[rchain] = new Set();
					}

					commands.pop(); // Finally, remove the last element.
				}

				// ===========================================================
			}

			// Increment counter to start another batch.
			if (nNODE && nNODE.node === "COMMAND" && !NODE.delimiter.value) {
				counter++;
			}
		} else if (type === "FLAG") {
			BATCHES[counter].flags.push(NODE); // Store command in current batch.

			// Increment counter to start another batch.
			if (nNODE && !["FLAG", "OPTION"].includes(nNODE.node)) counter++;
		} else if (type === "OPTION") {
			// Add the value to last flag in batch.
			let FLAGS = BATCHES[counter].flags;
			FLAGS[FLAGS.length - 1].args.push(NODE.value.value);
		}
	}

	// 3) Populate Sets SETS. ==================================================

	for (let i in BATCHES) {
		if (!Object.prototype.hasOwnProperty.call(BATCHES, i)) continue;

		let BATCH = BATCHES[i]; // Cache current loop char.
		let { commands: COMMANDS, flags: FLAGS } = BATCH; // Get commands/flags.

		for (let i = 0, l = FLAGS.length; i < l; i++) {
			let fNODE = FLAGS[i]; // Cache current loop char.
			let ARGS = fNODE.args; // Get flag arguments.
			// Build flag (hyphens + flag name).
			let flag = `${fNODE.hyphens.value}${fNODE.name.value}`;

			// Check if flag is actually a default/keyword and store it.
			if (fNODE.keyword.value) {
				COMMANDS.forEach(NODE => {
					DEFAULTS[NODE.command.value] = fNODE.value.value;
				});

				continue; // Note: Since it's a default it doesn't need to be
				// added to the SETS so stop iteration here.
			}

			// If the flag has any values build each flag + value.
			if (ARGS.length) {
				ARGS.forEach(ARG => {
					// Determine whether to add multi-flag indicator.
					baseflag(fNODE, COMMANDS, flag);

					// Add flag + value to Set.
					COMMANDS.forEach(NODE => {
						SETS[NODE.command.value].add(
							`${flag}${fNODE.assignment.value || ""}${ARG || ""}`
						);
					});
				});
			}
			// If flag does not contain any values...
			else {
				// If flag is a boolean...
				COMMANDS.forEach(NODE => {
					const cvalue = NODE.command.value;
					const bvalue = fNODE.boolean.value;
					const avalue = fNODE.assignment.value;

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
		if (command && Object.prototype.hasOwnProperty.call(SETS, command)) {
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
				if (!Object.prototype.hasOwnProperty.call(memtable, flags)) {
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
		if (Object.prototype.hasOwnProperty.call(SETTINGS, setting)) {
			CONFIG += `@${setting} = ${SETTINGS[setting]}\n`;
		}
	}

	// 6) Right trim all strings. ==============================================

	ACDEF = ACDEF.replace(/\s*$/g, "");
	CONFIG = CONFIG.replace(/\s*$/g, "");
	defs = defs.replace(/\s*$/g, "");

	return {
		acdef: {
			content: ACDEF,
			print: ACDEF
		},
		config: {
			content: CONFIG,
			print: CONFIG
		},
		keywords: {
			content: defs,
			print: defs
		},
		placeholders: PLACEHOLDERS
	};
};
