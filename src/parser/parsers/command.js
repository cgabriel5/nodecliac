"use strict";

const node = require("../helpers/nodes.js");
const p_flag = require("../parsers/flag.js");
const error = require("../helpers/error.js");
const add = require("../helpers/tree-add.js");
const tracer = require("../helpers/trace.js");
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
	let { l, text } = S;
	let state = "command";
	let N = node(S, "COMMAND");

	// Error if cc scope exists (brace not closed).
	bracechecks(S, null, "pre-existing-cs");

	for (; S.i < l; S.i++, S.column++) {
		let char = text.charAt(S.i);

		if (r_nl.test(char)) {
			N.end = rollback(S) && S.i;
			break; // Stop at nl char.
		}

		switch (state) {
			case "command":
				if (!N.command.value) {
					if (!/[:a-zA-Z]/.test(char)) error(S, __filename);

					N.command.start = N.command.end = S.i;
					N.command.value += char;
				} else {
					if (/[-_.:+\\/a-zA-Z0-9]/.test(char)) {
						N.command.end = S.i;
						N.command.value += char;

						// Note: When escaping anything but a dot do not
						// include the '\' as it is not needed. For example,
						// if the command is 'com\mand\.name' we should return
						// 'command\.name' and not 'com\mand\.name'.
						if (char === "\\") {
							let nchar = text.charAt(S.i + 1);

							// nchar must exist else escaping nothing.
							if (!nchar) error(S, __filename, 10);

							// Only dots can be escaped.
							if (nchar !== ".") {
								error(S, __filename, 10);

								// Remove last escape char as it isn't needed.
								let command = N.command.value.slice(0, -1);
								N.command.value = command;
							}
						}
					} else if (r_space.test(char)) {
						state = "chain-wsb";
						continue;
					} else if (char === "=") {
						state = "assignment";
						rollback(S);
					} else if (char === ",") {
						state = "delimiter";
						rollback(S);
					} else error(S, __filename);
				}

				break;

			case "chain-wsb":
				if (!r_space.test(char)) {
					if (char === "=") {
						state = "assignment";
						rollback(S);
					} else if (char === ",") {
						state = "delimiter";
						rollback(S);
					} else error(S, __filename);
				}

				break;

			case "assignment":
				N.assignment.start = N.assignment.end = S.i;
				N.assignment.value = char;
				state = "value-wsb";

				break;

			case "delimiter":
				N.delimiter.start = N.delimiter.end = S.i;
				N.delimiter.value = char;
				state = "eol-wsb";

				break;

			case "value-wsb":
				if (!r_space.test(char)) {
					state = "value";
					rollback(S);
				}

				break;

			case "value":
				// Note: Intermediary step - remove it?
				if (!/[-d[]/.test(char)) error(S, __filename);
				state = char === "[" ? "open-bracket" : "oneliner";
				rollback(S);

				break;

			case "open-bracket":
				// Note: Intermediary step - remove it?
				N.brackets.start = S.i;
				N.brackets.value = char;
				N.value.value = char;
				state = "open-bracket-wsb";

				break;

			case "open-bracket-wsb":
				if (!r_space.test(char)) {
					state = "close-bracket";
					rollback(S);
				}

				break;

			case "close-bracket":
				if (char !== "]") error(S, __filename);
				N.brackets.end = S.i;
				N.value.value += char;
				state = "eol-wsb";

				break;

			case "oneliner":
				tracer(S, "flag"); // Trace parser.
				N.flags.push(p_flag(S, "oneliner"));

				break;

			case "eol-wsb":
				if (!r_space.test(char)) error(S, __filename);

				break;
		}
	}

	add(S, N); // Add flags below.
	for (let i = 0, l = N.flags.length; i < l; i++) add(S, N.flags[i]);

	// If scope is created store ref to Node object.
	if (N.value.value === "[") S.scopes.command = N;
};
