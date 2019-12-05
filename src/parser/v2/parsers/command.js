"use strict";

const p_flag = require("../parsers/flag.js");

/**
 * Command-chain parser.
 *
 * ---------- Parsing Breakdown ------------------------------------------------
 * program.command = [ ]?
 * program.command = [
 * program.command = --flag
 * program.command =
 * program.command ,
 * program.command
 *                | |
 *                ^-^-Whitespace-Boundary 1/2
 * ^-Command-Chain
 *                 ^-Assignment
 *                   ^-Opening-Bracket
 *                    ^-Whitespace-Boundary 3
 *                     ^-Optional-Closing-Bracket?
 *                      ^-EOL-Whitespace-Boundary 4
 * -----------------------------------------------------------------------------
 *
 * @param  {object} STATE - Main loop state object.
 * @return {object} - Object containing parsed information.
 */
module.exports = STATE => {
	let { line, l, string, utils } = STATE; // Loop state vars.
	// Utility functions and constants.
	let { functions: F, constants: C } = utils;
	let { r_nl, r_whitespace } = C.regexp;
	let { issue, rollback, bracechecks } = F.loop;
	let { add } = F.tree;

	// Note: If command-chain scope exists, error as brace wasn't closed.
	bracechecks(STATE, null, "pre-existing-cs");

	// Parsing vars.
	let state = "command"; // Initial parsing state.
	let NODE = {
		node: "COMMAND",
		sigil: { start: null, end: null },
		command: { start: null, end: null, value: "" },
		name: { start: null, end: null, value: "" },
		brackets: { start: null, end: null, value: null },
		assignment: { start: null, end: null, value: null },
		delimiter: { start: null, end: null, value: null },
		value: { start: null, end: null, value: null },
		flags: [],
		line,
		startpoint: STATE.i,
		endpoint: null // Index where parsing ended.
	};

	// Loop over string.
	for (; STATE.i < l; STATE.i++) {
		let char = string.charAt(STATE.i); // Cache current loop char.

		// End loop on a newline char.
		if (r_nl.test(char)) {
			// Rollback to run newline char code block next iteration.
			NODE.endpoint = --STATE.i; // Store newline index.

			break;
		}

		STATE.column++; // Increment column position.

		switch (state) {
			case "command":
				// If name is empty check for first letter.
				if (!NODE.command.value) {
					// Name must start with pattern else give error.
					if (!/[:a-zA-Z]/.test(char)) issue.error(STATE);

					// Set index positions.
					NODE.command.start = STATE.i;
					NODE.command.end = STATE.i;

					NODE.command.value += char; // Start building string.
				}
				// Continue building setting command string.
				else {
					// If char is allowed keep building string.
					if (/[-_.:+\\/a-zA-Z0-9]/.test(char)) {
						// Set index positions.
						NODE.command.end = STATE.i;
						NODE.command.value += char; // Continue building string.

						// Note: When escaping anything but a dot do not
						// include the '\' as it is not needed. For example,
						// if the command is 'com\mand\.name' we should return
						// 'command\.name' and not 'com\mand\.name'.
						if (char === "\\") {
							let nchar = string.charAt(STATE.i + 1); // Next char.

							// Note: If next char doesn't exist the
							// '\' char is escaping nothing so error.
							if (!nchar) issue.error(STATE, 10);

							// Next char must be a space to be a valid escape sequence.
							if (nchar !== ".") {
								// Escaping anything but a dot isn't allowed, so error.
								issue.error(STATE, 10);

								// Remove last escape char as it isn't needed.
								let command = NODE.command.value.slice(0, -1);
								NODE.command.value = command;
							}
						}
					}
					// Note: If we encounter a whitespace character, everything
					// after this point must be a space until we encounter
					// an eq sign or the end-of-line (newline) character.
					else if (r_whitespace.test(char)) {
						state = "chain-wsb";
						continue;
					}
					// If char is an eq sign change state/reset index.
					else if (char === "=") {
						state = "assignment";

						rollback(STATE); // Rollback loop index.
					}
					// Anything else the character is not allowed.
					else if (char === ",") {
						state = "delimiter";

						rollback(STATE); // Rollback loop index.
					}
					// Note: Anything at this point is an invalid char.
					else issue.error(STATE);
				}

				break;

			case "chain-wsb":
				// At this point we are looking for the assignment operator
				// or a delimiter. Anything but whitespace, eq-sign, or
				// command are invalid chars.
				if (!r_whitespace.test(char)) {
					if (char === "=") {
						state = "assignment"; // Reset parsing state.

						rollback(STATE); // Rollback loop index.
					} else if (char === ",") {
						state = "delimiter"; // Reset parsing state.

						rollback(STATE); // Rollback loop index.
					}
					// Note: Anything at this point is an invalid char.
					else issue.error(STATE);
				}

				break;

			case "assignment":
				// Store index positions.
				NODE.assignment.start = STATE.i;
				NODE.assignment.end = STATE.i;
				NODE.assignment.value = char; // Store character.

				state = "value-wsb"; // Reset parsing state.

				break;

			case "delimiter":
				// Store index positions.
				NODE.delimiter.start = STATE.i;
				NODE.delimiter.end = STATE.i;
				NODE.delimiter.value = char; // Store character.

				state = "eol-wsb"; // Reset parsing state.

				break;

			case "value-wsb":
				// Ignore consecutive whitespace. Once a non-whitespace
				// character is hit, switch to value state.
				if (!r_whitespace.test(char)) {
					state = "value";

					rollback(STATE); // Rollback loop index.
				}

				break;

			case "value":
				// Note: This will be an intermediary step. May be removed?
				// Determine value type. If character is '[' then start
				// open-bracket case. Else if character is '-' then
				// commence 'oneliner' route.

				// Before determining path, check that character is valid.
				if (!/[-d[]/.test(char)) issue.error(STATE);

				state = char === "[" ? "open-bracket" : "oneliner"; // Reset parsing state.

				rollback(STATE); // Rollback loop index.

				break;

			case "open-bracket":
				// Note: This will be an intermediary step. May be removed?

				// Store index positions.
				NODE.brackets.start = STATE.i;
				NODE.brackets.value = char; // Store bracket character.
				NODE.value.value = char; // Store assignment character.

				state = "open-bracket-wsb"; // Reset parsing state.

				break;

			case "open-bracket-wsb":
				// Ignore consecutive whitespace. Once a non-whitespace
				// character is hit, switch to value state.
				if (!r_whitespace.test(char)) {
					state = "close-bracket";

					rollback(STATE); // Rollback loop index.
				}

				break;

			case "close-bracket":
				// Char must be a closing bracket ']' anything else is invalid.
				if (char !== "]") issue.error(STATE);

				// Store index positions.
				NODE.brackets.end = STATE.i;
				NODE.value.value += char; // Store character.

				state = "eol-wsb"; // Reset parsing state.

				break;

			case "oneliner":
				// Note: Reduce column counter by 1 since parser loop will
				// commence at the start of the first non whitespace char.
				// A char that has already been looped over in the main loop.
				STATE.column--;

				// Store result in var to access interpolated variable's value.
				NODE.flags.push(p_flag(STATE, "oneliner")); // Parse flag oneliner...

				break;

			case "eol-wsb":
				// Anything but trailing whitespace is invalid so give error.
				if (!r_whitespace.test(char)) issue.error(STATE);

				break;
		}
	}

	add(STATE, NODE);
	// Add any flags.
	for (let i = 0, l = NODE.flags.length; i < l; i++) {
		add(STATE, NODE.flags[i]);
	}

	// If command starts a scope block, store reference to node object.
	if (NODE.value.value === "[") STATE.scopes.command = NODE;

	return NODE;
};
