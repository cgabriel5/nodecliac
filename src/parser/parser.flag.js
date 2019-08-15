"use strict";

// Require needed modules.
let issue = require("./helper.issue.js");
// Get RegExp patterns.
let { r_nl } = require("./h.patterns.js");

/**
 * Parses flag set line to extract flag name, value, and its other components.
 *
 * ---------- Parsing States Breakdown -----------------------------------------
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
 * @param  {string} string - The line to parse.
 * @return {object} - Object containing parsed information.
 */
module.exports = (STATE, isoneliner) => {
	// require("./h.trace.js")(__filename); // Trace parser.

	// Note: If not a oneliner or there is no command scope then the
	// flag is being declared out of scope.
	if (!(isoneliner || STATE.scopes.command)) {
		issue.error(STATE, 0, __filename);
	}

	// Get global loop state variables.
	let { line, l, string } = STATE;

	// Parsing vars.
	let state = string.charAt(STATE.i) === "-" ? "hyphen" : "keyword"; // Initial parsing state.
	let stop; // Flag indicating whether to stop parser.
	let qchar;
	let warnings = []; // Collect all parsing warnings.
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
		endpoint: null // Then index at which parsing was ended.
	};

	// Loop over string.
	for (; STATE.i < l; STATE.i++) {
		let char = string.charAt(STATE.i); // Cache current loop item.

		// End loop on a new line char.
		if (stop || r_nl.test(char)) {
			// Note: When setting the endpoint make sure to subtract index
			// by 1 so that when it returns to its previous loop is can run
			// the newline character code block.
			NODE.endpoint = STATE.i - 1; // Store newline index.
			STATE.i = STATE.i - 1; // Store newline index.
			break;
		}

		STATE.column++; // Increment column position.

		switch (state) {
			case "hyphen":
				// // With RegExp to parse on unescaped '|' characters it would be
				// // something like this: String.split(/(?<=[^\\]|^|$)\|/);
				// // [https://stackoverflow.com/a/25895905]
				// // [https://stackoverflow.com/a/12281034]

				// // Get individual flag sets. Use unescaped '|' as the delimiter.
				// if (char === "|" && pchar !== "\\") {
				// 	// Run flag value parser from here...
				// 	let pvalue = pflagset();
				// }

				// Only hyphens are allowed at this point.
				if (!NODE.hyphens.value) {
					// Character must be one of the following:
					if (char !== "-") {
						// Note: Hitting this block means an invalid
						// character was encountered so give an error.
						issue.error(STATE, 0, __filename);
					}

					// Store index positions.
					NODE.hyphens.start = STATE.i;
					NODE.hyphens.end = STATE.i;
					// Start building the value string.
					NODE.hyphens.value = char;

					// Continue building hyphen string.
				} else {
					// Stop at anything other than following characters.
					if (char !== "-") {
						state = "name";

						// Note: Rollback index by 1 to allow parser to
						// start at new state on next iteration.
						STATE.i -= 1;
						STATE.column--;
					} else {
						// Store index positions.
						NODE.hyphens.end = STATE.i;
						// Continue building the value string.
						NODE.hyphens.value += char;
					}
				}

				break;

			case "keyword":
				// Only letters are allowed.
				let keyword_len = 7;
				let keyword = string.substr(STATE.i, keyword_len);

				// Note: If the keyword is not 'default' then error.
				if (keyword !== "default") {
					issue.error(STATE, 0, __filename);
				}

				// Store index positions.
				NODE.keyword.start = STATE.i;
				NODE.keyword.end = STATE.i + keyword_len - 1;
				// Store keyword value.
				NODE.keyword.value = keyword;

				// Note: A whitespace character must follow keyword.
				state = "keyword-spacer";

				// Note: Forward loop index to skip keyword characters.
				STATE.i += keyword_len - 1;

				break;

			case "keyword-spacer":
				// The character must be a whitespace character.
				if (!/[ \t]/.test(char)) {
					issue.error(STATE, 0, __filename);
				}

				// Now start looking the value.
				state = "wsb-prevalue";

				break;

			case "name":
				// Only hyphens are allowed at this point.
				if (!NODE.name.value) {
					// Character must be one of the following:
					if (!/[a-zA-Z]/.test(char)) {
						// Note: Hitting this block means an invalid
						// character was encountered so give an error.
						issue.error(STATE, 0, __filename);
					}

					// Store index positions.
					NODE.name.start = STATE.i;
					NODE.name.end = STATE.i;
					// Start building the value string.
					NODE.name.value = char;

					// Continue building hyphen string.
				} else {
					// If char is allowed keep building string.
					if (/[-a-zA-Z0-9]/.test(char)) {
						// Set name index positions.
						NODE.name.end = STATE.i;
						// Continue building setting name string.
						NODE.name.value += char;

						// If char is an eq sign change state/reset index.
					} else if (char === "=") {
						state = "assignment";

						// Note: Rollback index by 1 to allow parser to
						// start at new state on next iteration.
						STATE.i -= 1;
						STATE.column--;

						// If char is a question mark change state/reset index.
					} else if (char === "?") {
						state = "boolean-indicator";

						// Note: Rollback index by 1 to allow parser to
						// start at new state on next iteration.
						STATE.i -= 1;
						STATE.column--;

						// If char is a pipe change state/reset index.
					} else if (char === "|") {
						state = "pipe-delimiter";

						// Note: Rollback index by 1 to allow parser to
						// start at new state on next iteration.
						STATE.i -= 1;
						STATE.column--;

						// If char is whitespace change state/reset index.
					} else if (/[ \t]/.test(char)) {
						state = "wsb-postname";

						// Note: Rollback index by 1 to allow parser to
						// start at new state on next iteration.
						STATE.i -= 1;
						STATE.column--;

						// Anything else the character is not allowed.
					} else {
						// Note: Hitting this block means an invalid
						// character was encountered so give an error.
						issue.error(STATE, 0, __filename);
					}
				}

				break;

			case "wsb-postname":
				// Note: The only allowed characters here are whitespace(s).
				// Anything else like an eq-sign, boolean-indicator, or pipe
				// require a state change.
				if (!/[ \t]/.test(char)) {
					if (char === "=") {
						state = "assignment";

						// Note: Rollback index by 1 to allow parser to
						// start at new state on next iteration.
						STATE.i -= 1;
						STATE.column--;

						// 	// If char is a question mark change state/reset index.
						// } else if (char === "?") {
						// 	state = "boolean-indicator";

						// 	// Note: Rollback index by 1 to allow parser to
						// 	// start at new state on next iteration.
						// 	STATE.i -= 1;
						// 	STATE.column--;

						// If char is a pipe change state/reset index.
					} else if (char === "|") {
						state = "pipe-delimiter";

						// Note: Rollback index by 1 to allow parser to
						// start at new state on next iteration.
						STATE.i -= 1;
						STATE.column--;

						// Anything else the character is not allowed.
					} else {
						// Note: Hitting this block means an invalid
						// character was encountered so give an error.
						issue.error(STATE, 0, __filename);
					}
				}

				break;

			case "boolean-indicator":
				// Store index positions.
				NODE.boolean.start = STATE.i;
				NODE.boolean.end = STATE.i;
				// Store assignment character.
				NODE.boolean.value = char;

				// Note: A boolean-indicator means the flag does not contain
				// a value. More of a switch than a parameter.
				state = "pipe-delimiter";

				break;

			case "assignment":
				// Store index positions.
				NODE.assignment.start = STATE.i;
				NODE.assignment.end = STATE.i;
				// Store assignment character.
				NODE.assignment.value = char;

				// Now we look for the assignment operator.
				state = "multi-indicator";

				break;

			case "multi-indicator":
				// If character is indeed a '*' then store information,
				// else continue to value state.
				if (char === "*") {
					// Store index positions.
					NODE.multi.start = STATE.i;
					NODE.multi.end = STATE.i;
					// Store assignment character.
					NODE.multi.value = char;
				} else {
					// Note: Rollback index by 1 to allow parser to
					// start at new state on next iteration.
					STATE.i -= 1;
					STATE.column--;
				}

				// Now start looking the value.
				// state = "value";
				state = "wsb-prevalue";

				break;

			case "pipe-delimiter":
				// Note: Pipe-delimiter serves to delimit individual flag sets.
				// With RegExp to parse on unescaped '|' characters it would be
				// something like this: String.split(/(?<=[^\\]|^|$)\|/);
				// [https://stackoverflow.com/a/25895905]
				// [https://stackoverflow.com/a/12281034]

				if (char !== "|") {
					issue.error(STATE, 0, __filename);
				}

				stop = true;

				break;

			case "wsb-prevalue":
				// Note: Allow any whitespace until first non-whitespace
				// character is hit.
				if (!/[ \t]/.test(char)) {
					// Note: Rollback index by 1 to allow parser to
					// start at new state on next iteration.
					STATE.i -= 1;
					STATE.column--;

					state = "value";
				}

				break;

			case "value":
				// Value:
				// - List: (1,2,3)
				// - Command-flags: $("cat")
				// - Strings: "value"
				// - Escaped-values: val\ ue

				// Get the previous char.
				let pchar = string.charAt(STATE.i - 1);

				// Determine value type.
				if (!NODE.value.value) {
					if (char === "$") {
						NODE.value.type = "command-flag";
					} else if (char === "(") {
						NODE.value.type = "list";
					} else if (/["']/.test(char)) {
						NODE.value.type = "quoted";
					} else {
						NODE.value.type = "escaped";
					}

					// Store index positions.
					NODE.value.start = STATE.i;
					NODE.value.end = STATE.i;
					// Start building the value string.
					NODE.value.value = char;
				} else {
					// Check if character is a delimiter.
					if (char === "|" && pchar !== "\\") {
						// Stop building value and change state.
						state = "pipe-delimiter";

						// Note: Rollback index by 1 to allow parser to
						// start at new state on next iteration.
						STATE.i -= 1;
						STATE.column--;

						// stop = true;
						break;
					}

					// If flag is set and characters can still be consumed
					// then there is a syntax error. For example, string may
					// be improperly quoted/escaped so give error.
					if (end_comsuming) {
						issue.error(STATE, 0, __filename);
					}

					// Get string type.
					let stype = NODE.value.type;

					// Escaped string logic.
					if (stype === "escaped") {
						if (/[ \t]/.test(char) && pchar !== "\\") {
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
					// Continue building the value string.
					NODE.value.value += char;
				}

				break;
		}
	}

	// If flag starts a scope block, store reference to node object.
	if (NODE.value.value === "(") {
		// Store relevant information.
		NODE.brackets = {
			start: NODE.value.start,
			end: NODE.value.start,
			value: NODE.value.value
		};

		// Store reference to node object.
		STATE.scopes.flag = NODE;
	}

	// Validate extracted variable value.
	require("./helper.validate-value.js")(STATE, NODE);

	if (STATE.singletonflag) {
		// Add node to tree.
		require("./helper.tree-add.js")(STATE, NODE);

		// Finally, remove the singletonflag key from STATE object.
		delete STATE.singletonflag;
	}

	return NODE;

	// // Lookup variable's value.
	// let lookup = variables[`$${name}`];

	// Check that variable exists here.
	// if (!lookup) {}

	// // If not formatting then reset variable to actual value.
	// if (!formatting) {}

	// // Track used count.
	// let used_counter = variables.__used__[name];
	// variables.__used__[name] = used_counter + 1;
};
