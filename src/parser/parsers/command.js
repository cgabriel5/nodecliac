"use strict";

const node = require("../helpers/nodes.js");
const p_flag = require("../parsers/flag.js");
const add = require("../helpers/tree-add.js");
const error = require("../helpers/error.js");
const rollback = require("../helpers/rollback.js");
const bracechecks = require("../helpers/brace-checks.js");
const { r_nl, r_space } = require("../helpers/patterns.js");

/**
 * ----------------------------------------------------------- Parsing Breakdown
 * program.command
 * program.command ,
 * program.command =
 * program.command = [
 * program.command = [ ]?
 * program.command = --flag
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
 * @param  {object} S - State object.
 * @return {object} - Node object.
 */
module.exports = S => {
	let { line, l, text } = S;
	let state = "command";
	let N = node(S, "COMMAND");

	// Note: If command-chain scope exists, error as brace wasn't closed.
	bracechecks(S, null, "pre-existing-cs");

	for (; S.i < l; S.i++, S.column++) {
		let char = text.charAt(S.i);

		// Stop on a newline char.
		if (r_nl.test(char)) {
			N.endpoint = rollback(S) && S.i;
			break;
		}

		switch (state) {
			case "command":
				// If name is empty check for first letter.
				if (!N.command.value) {
					// Name must start with pattern else give error.
					if (!/[:a-zA-Z]/.test(char)) error(S, __filename);

					// Set index positions.
					N.command.start = S.i;
					N.command.end = S.i;

					N.command.value += char; // Start building string.
				}
				// Continue building setting command string.
				else {
					// If char is allowed keep building string.
					if (/[-_.:+\\/a-zA-Z0-9]/.test(char)) {
						// Set index positions.
						N.command.end = S.i;
						N.command.value += char; // Continue building string.

						// Note: When escaping anything but a dot do not
						// include the '\' as it is not needed. For example,
						// if the command is 'com\mand\.name' we should return
						// 'command\.name' and not 'com\mand\.name'.
						if (char === "\\") {
							let nchar = text.charAt(S.i + 1); // Next char.

							// Note: If next char doesn't exist the
							// '\' char is escaping nothing so error.
							if (!nchar) error(S, __filename, 10);

							// Next char must be a space to be a valid escape sequence.
							if (nchar !== ".") {
								// Escaping anything but a dot isn't allowed, so error.
								error(S, __filename, 10);

								// Remove last escape char as it isn't needed.
								let command = N.command.value.slice(0, -1);
								N.command.value = command;
							}
						}
					}
					// Note: If we encounter a whitespace character, everything
					// after this point must be a space until we encounter
					// an eq sign or the end-of-line (newline) character.
					else if (r_space.test(char)) {
						state = "chain-wsb";
						continue;
					}
					// If char is an eq sign change state/reset index.
					else if (char === "=") {
						state = "assignment";

						rollback(S); // Rollback loop index.
					}
					// Anything else the character is not allowed.
					else if (char === ",") {
						state = "delimiter";

						rollback(S); // Rollback loop index.
					}
					// Note: Anything at this point is an invalid char.
					else error(S, __filename);
				}

				break;

			case "chain-wsb":
				// At this point we are looking for the assignment operator
				// or a delimiter. Anything but whitespace, eq-sign, or
				// command are invalid chars.
				if (!r_space.test(char)) {
					if (char === "=") {
						state = "assignment"; // Reset parsing state.

						rollback(S); // Rollback loop index.
					} else if (char === ",") {
						state = "delimiter"; // Reset parsing state.

						rollback(S); // Rollback loop index.
					}
					// Note: Anything at this point is an invalid char.
					else error(S, __filename);
				}

				break;

			case "assignment":
				// Store index positions.
				N.assignment.start = S.i;
				N.assignment.end = S.i;
				N.assignment.value = char; // Store character.

				state = "value-wsb"; // Reset parsing state.

				break;

			case "delimiter":
				// Store index positions.
				N.delimiter.start = S.i;
				N.delimiter.end = S.i;
				N.delimiter.value = char; // Store character.

				state = "eol-wsb"; // Reset parsing state.

				break;

			case "value-wsb":
				// Ignore consecutive whitespace. Once a non-whitespace
				// character is hit, switch to value state.
				if (!r_space.test(char)) {
					state = "value";

					rollback(S); // Rollback loop index.
				}

				break;

			case "value":
				// Note: This will be an intermediary step. May be removed?
				// Determine value type. If character is '[' then start
				// open-bracket case. Else if character is '-' then
				// commence 'oneliner' route.

				// Before determining path, check that character is valid.
				if (!/[-d[]/.test(char)) error(S, __filename);

				state = char === "[" ? "open-bracket" : "oneliner"; // Reset parsing state.

				rollback(S); // Rollback loop index.

				break;

			case "open-bracket":
				// Note: This will be an intermediary step. May be removed?

				// Store index positions.
				N.brackets.start = S.i;
				N.brackets.value = char; // Store bracket character.
				N.value.value = char; // Store assignment character.

				state = "open-bracket-wsb"; // Reset parsing state.

				break;

			case "open-bracket-wsb":
				// Ignore consecutive whitespace. Once a non-whitespace
				// character is hit, switch to value state.
				if (!r_space.test(char)) {
					state = "close-bracket";

					rollback(S); // Rollback loop index.
				}

				break;

			case "close-bracket":
				// Char must be a closing bracket ']' anything else is invalid.
				if (char !== "]") error(S, __filename);

				// Store index positions.
				N.brackets.end = S.i;
				N.value.value += char; // Store character.

				state = "eol-wsb"; // Reset parsing state.

				break;

			case "oneliner":
				// Note: Reduce column counter by 1 since parser loop will
				// commence at the start of the first non whitespace char.
				// A char that has already been looped over in the main loop.
				S.column--;

				// Store result in var to access interpolated variable's value.
				N.flags.push(p_flag(S, "oneliner")); // Parse flag oneliner...

				break;

			case "eol-wsb":
				// Anything but trailing whitespace is invalid so give error.
				if (!r_space.test(char)) error(S, __filename);

				break;
		}
	}

	add(S, N);
	// Add any flags.
	for (let i = 0, l = N.flags.length; i < l; i++) {
		add(S, N.flags[i]);
	}

	// If command starts a scope block, store reference to node object.
	if (N.value.value === "[") S.scopes.command = N;

	return N;
};
