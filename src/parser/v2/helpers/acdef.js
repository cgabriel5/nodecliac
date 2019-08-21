"use strict";

/**
 * Generate .acdef, .config.acdef file contents from parse tree ob nodes.
 *
 * @param  {object} STATE - Main loop state object.
 * @param  {string} commandname - Name of <command>.acdef being parsed.
 * @return {object} - Object containing acdef, config, and keywords contents.
 */
module.exports = (STATE, commandname) => {
	// Vars.
	let counter = 0;
	let nodes = [];

	let ACDEF = [];
	let TABLE = {};
	let DEFAULTS = {};
	let SETS = {};
	let BATCHES = {};
	let SETTINGS = {};
	let TREE = STATE.DB.tree;

	let has_root = false;
	// RegExp to match main command/first command in chain to remove.
	let r = new RegExp(
		// Note: Properly escape '+' characters for commands like 'g++'.
		`^(${commandname.replace(/(\+)/g, "\\$1")}|[-_a-zA-Z0-9]+)`
	);
	// The .acdef/.config.acdef file header.
	let header = `# DON'T EDIT FILE —— GENERATED: ${new Date()}(${Date.now()})\n\n`;

	/**
	 * Add base flag to Set (adds '--flag=' or '--flag=*' to Set).
	 *
	 * @param  {object} fNODE - The flag object Node.
	 * @param  {array} COMMANDS - The list of commands to attach flags to.
	 * @param  {string} flag - The flag (hyphens + flag name).
	 * @return {undefined} - Nothing is returned.
	 */
	let baseflag = (fNODE, COMMANDS, flag) => {
		// Check whether flag is a multi-flag.
		let ismulti = fNODE.multi.value;

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
	 */
	let sorter = (a, b) => {
		// Give multi-flags higher sorting precedence.
		// [https://stackoverflow.com/a/9604891]
		// [https://stackoverflow.com/a/24292023]
		// [http://www.javascripttutorial.net/javascript-array-sort/]
		return ~~b.endsWith("=*") - ~~a.endsWith("=*") || a.localeCompare(b);
	};

	/**
	 * Sort function.
	 *
	 * @param  {string} a - Item a.
	 * @param  {string} b - Item b.
	 * @return {number} - The sort number result.
	 */
	let aplhasort = (a, b) => {
		return a.localeCompare(b);
	};

	// 1) Filter out unnecessary Nodes. ========================================
	TREE.nodes.forEach(NODE => {
		let type = NODE.node;

		if (["COMMAND", "FLAG", "OPTION", "SETTING"].includes(type)) {
			if (type !== "SETTING") {
				nodes.push(NODE);

				// Add setting/value to object.
			} else {
				SETTINGS[NODE.name.value] = NODE.value.value;
			}
		}
	});

	// 2) Batch commands with their flags. =====================================
	for (let i = 0, l = nodes.length; i < l; i++) {
		// Cache current loop item.
		let NODE = nodes[i];
		let nNODE = nodes[i + 1] || {};
		let type = NODE.node;
		let ntype = nNODE.node;

		if (type === "COMMAND") {
			// Store command into current batch.
			if (!BATCHES[counter]) {
				BATCHES[counter] = {
					commands: [NODE],
					flags: []
				};
			} else {
				BATCHES[counter].commands.push(NODE);
			}

			// Add command to SETS if not already.
			if (!SETS.hasOwnProperty(NODE.command.value)) {
				SETS[NODE.command.value] = new Set();

				// Note: Create any missing parent chains. =====================
				let commands = NODE.command.value.split(/(?<!\\)\./);
				// Remove the last command as it was already made.
				commands.pop();
				// For remaining commands, create Set if not already.
				for (let i = commands.length - 1; i > -1; i--) {
					// Cache current loop item.
					// let cmd = commands[i];
					let remainder_chain = commands.join(".");

					if (!SETS.hasOwnProperty(remainder_chain)) {
						SETS[remainder_chain] = new Set();
					}

					// Finally, remove the last element.
					commands.pop();
				} // ===========================================================
			}

			// Increment counter to start another batch.
			if (nNODE && nNODE.node === "COMMAND" && !NODE.delimiter.value) {
				counter++;
			}
		} else if (type === "FLAG") {
			// Store command into current batch.
			BATCHES[counter].flags.push(NODE);

			// Increment counter to start another batch.
			if (nNODE && !["FLAG", "OPTION"].includes(nNODE.node)) {
				counter++;
			}
		} else if (type === "OPTION") {
			// Add the value to the last flag in batch.
			let FLAGS = BATCHES[counter].flags;

			let FLAG = FLAGS[FLAGS.length - 1];
			FLAG.args.push(NODE.value.value);
		}
	}

	// 3) Populate Sets SETS. ==================================================
	for (let i in BATCHES) {
		//The current property is not a direct property of p
		if (!BATCHES.hasOwnProperty(i)) {
			continue;
		}

		// Cache current loop item.
		let BATCH = BATCHES[i];
		// Get commands/flags.
		let COMMANDS = BATCH.commands;
		let FLAGS = BATCH.flags;

		for (let i = 0, l = FLAGS.length; i < l; i++) {
			let fNODE = FLAGS[i]; // Cache current loop item.
			let ARGS = fNODE.args; // Get flag arguments.
			// Build flag (hyphens + flag name).
			let flag = `${fNODE.hyphens.value}${fNODE.name.value}`;

			// Check if flag is actually a default/keyword.
			if (fNODE.keyword.value) {
				COMMANDS.forEach(NODE => {
					// Store keyword.
					DEFAULTS[NODE.command.value] = fNODE.value.value;
				});

				// Note: Since it is a default it does not need to be
				// added to the SETS so stop iteration here.
				continue;
			}

			// If the flag has any values build each flag + value.
			if (ARGS.length) {
				ARGS.forEach(ARG => {
					// Determine whether to add multi-flag indicator.
					baseflag(fNODE, COMMANDS, flag);

					COMMANDS.forEach(NODE => {
						// Add flag + value to Set.
						SETS[NODE.command.value].add(
							`${flag}${fNODE.assignment.value || ""}${ARG || ""}`
						);
					});
				});

				// If flag does not contain any values...
			} else {
				// If flag is a boolean...
				COMMANDS.forEach(NODE => {
					SETS[NODE.command.value].add(
						`${flag}${
							fNODE.boolean.value
								? "?"
								: fNODE.assignment.value
								? "="
								: ""
						}`
					);
				});
			}
		}
	}

	// 4) Generate final ACDEF before sorting. =================================
	for (let command in SETS) {
		if (command && SETS.hasOwnProperty(command)) {
			// Get the Sets object.
			let SET = SETS[command];
			let flags = "--";

			// If Set has items then it has flags so convert to an array.
			if (SET.size) {
				// [https://stackoverflow.com/a/47243199]
				// [https://stackoverflow.com/a/21194765]
				flags = [...SET].sort(sorter).join("|");
			}

			// Remove the main command from the command chain. However,
			// when the command name is not the main command in (i.e.
			// when running on a test file) just remove the first command
			// name in the chain.
			let row = `${command.replace(r, "")} ${flags}`;

			// Remove multiple ' --' command chains. This will happen for
			// test files with multiple main commands.
			if (row === " --" && !has_root) {
				has_root = true;
			} else if (row === " --" && has_root) {
				continue;
			}

			ACDEF.push(row);
		}
	}
	ACDEF = header + ACDEF.sort(aplhasort).join("\n");

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
		if (SETTINGS.hasOwnProperty(setting)) {
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
		}
	};
};
