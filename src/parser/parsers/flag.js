"use strict";

const node = require("../helpers/nodes.js");
const add = require("../helpers/tree-add.js");
const error = require("../helpers/error.js");
const rollback = require("../helpers/rollback.js");
const validate = require("../helpers/validate-value.js");
const { r_nl, r_space, r_letter, r_quote } = require("../helpers/patterns.js");

/**
 * ----------------------------------------------------------- Parsing Breakdown
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
 * @param  {object} S - State object.
 * @param  {string} isoneliner - Whether to treat flag as a oneliner.
 * @return {object} - Node object.
 */
module.exports = (S, isoneliner) => {
	let { line, l, text } = S;
	let state = text.charAt(S.i) === "-" ? "hyphen" : "keyword"; // Initial parsing state.
	let stop; // Flag indicating whether to stop parser.
	let end_comsuming;
	let N = node(S, "FLAG");

	// Note: If not a oneliner or no command scope, flag is being declared out of scope.
	if (!(isoneliner || S.scopes.command)) error(S, __filename, 10);

	// Note: If flag scope already exists another flag cannot be declared.
	if (S.scopes.flag) error(S, __filename, 11);

	// Loop over string.
	for (; S.i < l; S.i++) {
		let char = text.charAt(S.i); // Cache current loop char.

		// End loop on a newline char.
		if (stop || r_nl.test(char)) {
			N.endpoint = --S.i; // Rollback (run '\n' parser next).

			break;
		}

		S.column++; // Increment column position.

		switch (state) {
			case "hyphen":
				// With RegExp to parse on unescaped '|' characters it would be
				// something like this: String.split(/(?<=[^\\]|^|$)\|/);
				// [https://stackoverflow.com/a/25895905]
				// [https://stackoverflow.com/a/12281034]

				// Only hyphens are allowed at this point.
				if (!N.hyphens.value) {
					// If char is not a hyphen, error.
					if (char !== "-") error(S, __filename);

					// Store index positions.
					N.hyphens.start = S.i;
					N.hyphens.end = S.i;
					N.hyphens.value = char; // Start building string.
				}
				// Continue building string.
				else {
					// Stop at anything other than following characters.
					if (char !== "-") {
						state = "name";

						rollback(S); // Rollback loop index.
					} else {
						// Store index positions.
						N.hyphens.end = S.i;
						N.hyphens.value += char; // Continue building string.
					}
				}

				break;

			case "keyword":
				{
					// Only letters are allowed.
					let keyword_len = 7;
					let keyword = text.substr(S.i, keyword_len);

					// Note: If the keyword is not 'default' then error.
					if (keyword !== "default") error(S, __filename);

					// Store index positions.
					N.keyword.start = S.i;
					N.keyword.end = S.i + keyword_len - 1;
					N.keyword.value = keyword; // Store keyword.

					state = "keyword-spacer"; // Reset parsing state.

					// Note: Forward loop index to skip keyword characters.
					S.i += keyword_len - 1;
					S.column += keyword_len - 1;
				}

				break;

			case "keyword-spacer":
				// Note: Character must be a whitespace character, else error.
				if (!r_space.test(char)) error(S, __filename);

				state = "wsb-prevalue"; // Reset parsing state.

				break;

			case "name":
				// Only hyphens are allowed at this point.
				if (!N.name.value) {
					// If char is not a hyphen, error.
					if (!r_letter.test(char)) error(S, __filename);

					// Store index positions.
					N.name.start = S.i;
					N.name.end = S.i;
					N.name.value = char; // Start building string.
				}
				// Continue building string.
				else {
					// If char is allowed keep building string.
					if (/[-.a-zA-Z0-9]/.test(char)) {
						// Set name index positions.
						N.name.end = S.i;
						N.name.value += char; // Continue building string.
					}
					// If char is an eq sign change state/reset index.
					else if (char === "=") {
						state = "assignment"; // Reset parsing state.

						rollback(S); // Rollback loop index.
					}
					// If char is a question mark change state/reset index.
					else if (char === "?") {
						state = "boolean-indicator"; // Reset parsing state.

						rollback(S); // Rollback loop index.
					}
					// If char is a pipe change state/reset index.
					else if (char === "|") {
						state = "pipe-delimiter"; // Reset parsing state.

						rollback(S); // Rollback loop index.
					}
					// If char is whitespace change state/reset index.
					else if (r_space.test(char)) {
						state = "wsb-postname"; // Reset parsing state.

						rollback(S); // Rollback loop index.
					}
					// Note: Anything at this point is an invalid char.
					else error(S, __filename);
				}

				break;

			case "wsb-postname":
				// Note: The only allowed characters here are whitespace(s).
				// Anything else like an eq-sign, boolean-indicator, or pipe
				// require a state change.
				if (!r_space.test(char)) {
					if (char === "=") {
						state = "assignment"; // Reset parsing state.

						rollback(S); // Rollback loop index.

						// If char is a pipe change state/reset index.
					} else if (char === "|") {
						state = "pipe-delimiter"; // Reset parsing state.

						rollback(S); // Rollback loop index.
					}
					// Note: Anything at this point is an invalid char.
					else error(S, __filename);
				}

				break;

			case "boolean-indicator":
				// Store index positions.
				N.boolean.start = S.i;
				N.boolean.end = S.i;
				N.boolean.value = char; // Store character.

				state = "pipe-delimiter"; // Reset parsing state.

				break;

			case "assignment":
				// Store index positions.
				N.assignment.start = S.i;
				N.assignment.end = S.i;
				N.assignment.value = char; // Store character.

				state = "multi-indicator"; // Reset parsing state.

				break;

			case "multi-indicator":
				// If character is a '*' store information, else go to value state.
				if (char === "*") {
					// Store index positions.
					N.multi.start = S.i;
					N.multi.end = S.i;
					N.multi.value = char; // Store character.

					state = "wsb-prevalue"; // Reset parsing state.
				} else {
					rollback(S); // Rollback loop index.

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

				if (char !== "|") error(S, __filename);
				stop = true; // Set parsing stop flag.

				break;

			case "wsb-prevalue":
				// Note: Allow any whitespace until first non-whitespace
				// character is hit.
					rollback(S);
					rollback(S); // Rollback loop index.

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
					let pchar = text.charAt(S.i - 1);

					// Determine value type.
					if (!N.value.value) {
						let type = "escaped"; // Set default.

						if (char === "$") type = "command-flag";
						else if (char === "(") type = "list";
						else if (r_quote.test(char)) type = "quoted";

						N.value.type = type; // Set type.

						// Store index positions.
						N.value.start = S.i;
						N.value.end = S.i;
						N.value.value = char; // Start building string.
					} else {
						// Check if character is a delimiter.
						if (char === "|" && pchar !== "\\") {
							state = "pipe-delimiter"; // Reset parsing state.

							rollback(S); // Rollback loop index.

							break;
						}

						// If flag is set and characters can still be consumed
						// then there is a syntax error. For example, string may
						// be improperly quoted/escaped so give error.
						if (end_comsuming) error(S, __filename);

						// Get string type.
						let stype = N.value.type;

						// Escaped string logic.
						if (stype === "escaped") {
							if (r_space.test(char) && pchar !== "\\") {
								end_comsuming = true; // Set flag.
							}

							// Quoted string logic.
						} else if (stype === "quoted") {
							let value_fchar = N.value.value.charAt(0);
							if (char === value_fchar && pchar !== "\\") {
								end_comsuming = true; // Set flag.
							}
						}

						// Store index positions.
						N.value.end = S.i;
						N.value.value += char; // Continue building string.
					}
				}

				break;
		}
	}

	// Note: If flag starts a scope block, store reference to node object.
	if (N.value.value === "(") {
		// Store relevant information.
		N.brackets = {
			start: N.value.start,
			end: N.value.start,
			value: N.value.value
		};

		S.scopes.flag = N; // Store reference to node object.
	}

	validate(S, N); // Validate extracted variable value.

	if (S.singletonflag) {
		add(S, N); // Add node to tree.

		// Finally, remove the singletonflag key from S object.
		delete S.singletonflag;

		// Add property to help distinguish node if later needed.
		N.singletonflag = true;
	}

	return N;
};
