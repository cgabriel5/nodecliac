"use strict";

const add = require("../helpers/tree-add.js");
const error = require("../helpers/error.js");
const rollback = require("../helpers/rollback.js");
const validate = require("../helpers/validate-value.js");
const bracechecks = require("../helpers/brace-checks.js");
const {
	r_nl,
	r_whitespace,
	r_letter,
	r_quote
} = require("../helpers/patterns.js");

/**
 * Flag parser.
 *
 * ---------- Parsing Breakdown ------------------------------------------------
 * --flag
 * --flag ?
 * --flag =* "string"
 * --flag =* 'string'
 * --flag =  $(flag-command)
 * --flag =  (flag-options-list)
 *       | |                    ^-EOL-Whitespace-Boundary 3.
 *       ^-^-Whitespace-Boundary 1/2.
 * ^-Symbol.
 *  ^-Name.
 *        ^-Assignment.
 *           ^-Value.
 * -----------------------------------------------------------------------------
 *
 * @param  {object} STATE - Main loop state object.
 * @param  {string} isoneliner - Whether to treat flag as a oneliner.
 * @return {object} - Object containing parsed information.
 */
module.exports = (STATE, isoneliner) => {
	let { line, l, string, utils } = STATE; // Loop state vars.

	// Note: If not a oneliner or no command scope, flag is being declared out of scope.
	if (!(isoneliner || STATE.scopes.command)) error(STATE, __filename, 10);

	// Note: If flag scope already exists another flag cannot be declared.
	if (STATE.scopes.flag) error(STATE, __filename, 11);

	// Parsing vars.
	let state = string.charAt(STATE.i) === "-" ? "hyphen" : "keyword"; // Initial parsing state.
	let stop; // Flag indicating whether to stop parser.
	let end_comsuming;
	let NODE = {
		node: "FLAG",
		hyphens: { start: null, end: null, value: null },
		variable: { start: null, end: null, value: null },
		name: { start: null, end: null, value: null },
		boolean: { start: null, end: null, value: null },
		assignment: { start: null, end: null, value: null },
		multi: { start: null, end: null, value: null },
		brackets: { start: null, end: null, value: null },
		value: { start: null, end: null, value: null, type: null },
		keyword: { start: null, end: null, value: null },
		line,
		startpoint: STATE.i,
		endpoint: null // Index where parsing ended.
	};

	// Loop over string.
	for (; STATE.i < l; STATE.i++) {
		let char = string.charAt(STATE.i); // Cache current loop char.

		// End loop on a newline char.
		if (stop || r_nl.test(char)) {
			// Rollback to run newline char code block next iteration.
			NODE.endpoint = --STATE.i; // Store newline index.

			break;
		}

		STATE.column++; // Increment column position.

		switch (state) {
			case "hyphen":
				// With RegExp to parse on unescaped '|' characters it would be
				// something like this: String.split(/(?<=[^\\]|^|$)\|/);
				// [https://stackoverflow.com/a/25895905]
				// [https://stackoverflow.com/a/12281034]

				// Only hyphens are allowed at this point.
				if (!NODE.hyphens.value) {
					// If char is not a hyphen, error.
					if (char !== "-") error(STATE, __filename);

					// Store index positions.
					NODE.hyphens.start = STATE.i;
					NODE.hyphens.end = STATE.i;
					NODE.hyphens.value = char; // Start building string.
				}
				// Continue building string.
				else {
					// Stop at anything other than following characters.
					if (char !== "-") {
						state = "name";

						rollback(STATE); // Rollback loop index.
					} else {
						// Store index positions.
						NODE.hyphens.end = STATE.i;
						NODE.hyphens.value += char; // Continue building string.
					}
				}

				break;

			case "keyword":
				{
					// Only letters are allowed.
					let keyword_len = 7;
					let keyword = string.substr(STATE.i, keyword_len);

					// Note: If the keyword is not 'default' then error.
					if (keyword !== "default") error(STATE, __filename);

					// Store index positions.
					NODE.keyword.start = STATE.i;
					NODE.keyword.end = STATE.i + keyword_len - 1;
					NODE.keyword.value = keyword; // Store keyword.

					state = "keyword-spacer"; // Reset parsing state.

					// Note: Forward loop index to skip keyword characters.
					STATE.i += keyword_len - 1;
					STATE.column += keyword_len - 1;
				}

				break;

			case "keyword-spacer":
				// Note: Character must be a whitespace character, else error.
				if (!r_whitespace.test(char)) error(STATE, __filename);

				state = "wsb-prevalue"; // Reset parsing state.

				break;

			case "name":
				// Only hyphens are allowed at this point.
				if (!NODE.name.value) {
					// If char is not a hyphen, error.
					if (!r_letter.test(char)) error(STATE, __filename);

					// Store index positions.
					NODE.name.start = STATE.i;
					NODE.name.end = STATE.i;
					NODE.name.value = char; // Start building string.
				}
				// Continue building string.
				else {
					// If char is allowed keep building string.
					if (/[-.a-zA-Z0-9]/.test(char)) {
						// Set name index positions.
						NODE.name.end = STATE.i;
						NODE.name.value += char; // Continue building string.
					}
					// If char is an eq sign change state/reset index.
					else if (char === "=") {
						state = "assignment"; // Reset parsing state.

						rollback(STATE); // Rollback loop index.
					}
					// If char is a question mark change state/reset index.
					else if (char === "?") {
						state = "boolean-indicator"; // Reset parsing state.

						rollback(STATE); // Rollback loop index.
					}
					// If char is a pipe change state/reset index.
					else if (char === "|") {
						state = "pipe-delimiter"; // Reset parsing state.

						rollback(STATE); // Rollback loop index.
					}
					// If char is whitespace change state/reset index.
					else if (r_whitespace.test(char)) {
						state = "wsb-postname"; // Reset parsing state.

						rollback(STATE); // Rollback loop index.
					}
					// Note: Anything at this point is an invalid char.
					else error(STATE, __filename);
				}

				break;

			case "wsb-postname":
				// Note: The only allowed characters here are whitespace(s).
				// Anything else like an eq-sign, boolean-indicator, or pipe
				// require a state change.
				if (!r_whitespace.test(char)) {
					if (char === "=") {
						state = "assignment"; // Reset parsing state.

						rollback(STATE); // Rollback loop index.

						// If char is a pipe change state/reset index.
					} else if (char === "|") {
						state = "pipe-delimiter"; // Reset parsing state.

						rollback(STATE); // Rollback loop index.
					}
					// Note: Anything at this point is an invalid char.
					else error(STATE, __filename);
				}

				break;

			case "boolean-indicator":
				// Store index positions.
				NODE.boolean.start = STATE.i;
				NODE.boolean.end = STATE.i;
				NODE.boolean.value = char; // Store character.

				state = "pipe-delimiter"; // Reset parsing state.

				break;

			case "assignment":
				// Store index positions.
				NODE.assignment.start = STATE.i;
				NODE.assignment.end = STATE.i;
				NODE.assignment.value = char; // Store character.

				state = "multi-indicator"; // Reset parsing state.

				break;

			case "multi-indicator":
				// If character is a '*' store information, else go to value state.
				if (char === "*") {
					// Store index positions.
					NODE.multi.start = STATE.i;
					NODE.multi.end = STATE.i;
					NODE.multi.value = char; // Store character.

					state = "wsb-prevalue"; // Reset parsing state.
				} else {
					rollback(STATE); // Rollback loop index.

					// Reset parsing state (based on character).
					if (char === "|") state = "pipe-delimiter";
					else state = "wsb-prevalue";
				}

				break;

			case "pipe-delimiter":
				// Note: Pipe-delimiter serves to delimit individual flag sets.
				// With RegExp to parse on unescaped '|' characters it would be
				// something like this: String.split(/(?<=[^\\]|^|$)\|/);
				// [https://stackoverflow.com/a/25895905]
				// [https://stackoverflow.com/a/12281034]

				if (char !== "|") error(STATE, __filename);
				stop = true; // Set parsing stop flag.

				break;

			case "wsb-prevalue":
				// Note: Allow any whitespace until first non-whitespace
				// character is hit.
				if (!r_whitespace.test(char)) {
					rollback(STATE); // Rollback loop index.

					// Reset parsing state (based on character).
					if (char === "|") state = "pipe-delimiter";
					else state = "value";
				}

				break;

			case "value":
				{
					// Value:
					// - List:            => (1,2,3)
					// - Command-flags:   => $("cat")
					// - Strings:         => "value"
					// - Escaped-values:  => val\ ue

					// Get the previous char.
					let pchar = string.charAt(STATE.i - 1);

					// Determine value type.
					if (!NODE.value.value) {
						let type = "escaped"; // Set default.

						if (char === "$") type = "command-flag";
						else if (char === "(") type = "list";
						else if (r_quote.test(char)) type = "quoted";

						NODE.value.type = type; // Set type.

						// Store index positions.
						NODE.value.start = STATE.i;
						NODE.value.end = STATE.i;
						NODE.value.value = char; // Start building string.
					} else {
						// Check if character is a delimiter.
						if (char === "|" && pchar !== "\\") {
							state = "pipe-delimiter"; // Reset parsing state.

							rollback(STATE); // Rollback loop index.

							break;
						}

						// If flag is set and characters can still be consumed
						// then there is a syntax error. For example, string may
						// be improperly quoted/escaped so give error.
						if (end_comsuming) error(STATE, __filename);

						// Get string type.
						let stype = NODE.value.type;

						// Escaped string logic.
						if (stype === "escaped") {
							if (r_whitespace.test(char) && pchar !== "\\") {
								end_comsuming = true; // Set flag.
							}

							// Quoted string logic.
						} else if (stype === "quoted") {
							let value_fchar = NODE.value.value.charAt(0);
							if (char === value_fchar && pchar !== "\\") {
								end_comsuming = true; // Set flag.
							}
						}

						// Store index positions.
						NODE.value.end = STATE.i;
						NODE.value.value += char; // Continue building string.
					}
				}

				break;
		}
	}

	// Note: If flag starts a scope block, store reference to node object.
	if (NODE.value.value === "(") {
		// Store relevant information.
		NODE.brackets = {
			start: NODE.value.start,
			end: NODE.value.start,
			value: NODE.value.value
		};

		STATE.scopes.flag = NODE; // Store reference to node object.
	}

	validate(STATE, NODE); // Validate extracted variable value.

	if (STATE.singletonflag) {
		add(STATE, NODE); // Add node to tree.

		// Finally, remove the singletonflag key from STATE object.
		delete STATE.singletonflag;

		// Add property to help distinguish node if later needed.
		NODE.singletonflag = true;
	}

	return NODE;
};
