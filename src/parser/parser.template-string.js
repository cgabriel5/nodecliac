"use strict";

// Require needed modules.
let issue = require("./helper.issue.js");
// Get RegExp patterns.
let { r_nl } = require("./h.patterns.js");

/**
 * Parses flag set line to extract flag name, value, and its other components.
 *
 * ---------- Parsing States Breakdown -----------------------------------------
 * ${ variable }
 *   |        |
 *   ^--------^-Whitespace-Boundary 1/2
 * ^-Symbol
 *    ^-Name  ^-Closing-Brace
 * -----------------------------------------------------------------------------
 *
 * @param  {string} string - The line to parse.
 * @return {object} - Object containing parsed information.
 */
module.exports = STATE => {
	// require("./h.trace.js")(__filename); // Trace parser.

	// Get global loop state variables.
	let { line, l, string } = STATE;

	// Parsing vars.
	let state = "dollar-sign"; // Initial parsing state.
	let stop; // Flag indicating whether to stop parser.
	let qchar;
	let warnings = []; // Collect all parsing warnings.
	let NODE = {
		node: "TEMPLATE-STRING",
		begin: { start: null, end: null, value: null },
		end: { start: null, end: null, value: null },
		variable: { start: null, end: null, value: null },
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
			case "dollar-sign":
				// Store '$' symbol (part of begin '${').
				NODE.begin.start = STATE.i;
				NODE.begin.end = STATE.i;

				// Start building setting name string.
				NODE.begin.value = char;

				// Now look for next part of beginning: '{'.
				state = "open-brace";

				break;

			case "open-brace":
				// Note: Character after the '$' must be an open brace. If
				// not the synatx is invalid so give an error.
				if (char !== "{") {
					issue.error(STATE);
				}

				// Set name index positions.
				NODE.begin.end = STATE.i;
				// Start building setting name string.
				NODE.begin.value += char;

				// Set new state.
				state = "open-brace-wsb";

				break;

			case "open-brace-wsb":
				// Ignore consecutive whitespace. Once a non-whitespace
				// character is hit, switch to variable state.
				if (!/[ \t]/.test(char)) {
					state = "variable";

					// Note: Rollback index by 1 to allow parser to
					// start at assignment case on next iteration.
					STATE.i -= 1;
					STATE.column--;
				}

				break;

			case "variable":
				// If this is the first char is must be either one of the
				// following: _ or a-zA-Z.
				if (!NODE.variable.value) {
					// Character must be one of the following:
					if (!/[_a-zA-Z]/.test(char)) {
						// Note: Hitting this block means an invalid
						// character was encountered so give an error.
						issue.error(STATE);
					}

					// Store index positions.
					NODE.variable.start = STATE.i;
					NODE.variable.end = STATE.i;
					// Start building the value string.
					NODE.variable.value = char;

					// Continue building variable string.
				} else {
					// Stop at anything other than following characters.
					if (!/[_a-zA-Z]/.test(char)) {
						state = "variable-wsb";

						// Note: Rollback index by 1 to allow parser to
						// start at assignment case on next iteration.
						STATE.i -= 1;
						STATE.column--;
					} else {
						// Store index positions.
						NODE.variable.end = STATE.i;
						// Continue building the value string.
						NODE.variable.value += char;
					}
				}

				break;

			case "variable-wsb":
				// Only characters allowed are whitespace. Anything else
				// will change state.
				if (!/[ \t]/.test(char)) {
					state = "close-brace";

					// Note: Rollback index by 1 to allow parser to
					// start at assignment case on next iteration.
					STATE.i -= 1;
					STATE.column--;
				}

				break;

			case "close-brace":
				// Note: Anything other than '}' is invalid so give an error.
				if (char !== "}") {
					issue.error(STATE);
				}

				// Set name index positions.
				NODE.end.start = STATE.i;
				NODE.end.end = STATE.i;
				// Start building setting name string.
				NODE.end.value = char;

				// Note: Once template-string has been fully parsed stop
				// this parser to return to parent parser.
				stop = true;

				break;
		}
	}

	return NODE;

	// // Lookup variable's value.
	// let lookup = variables[`$${name}`];

	// // Check that variable exists here.
	// if (!lookup) {
	// 	// Reset index to point to original index.
	// 	ci = indices["template-string"].variable.start;

	// 	return issue("error", 9, void 0);
	// }

	// // If not formatting then reset variable to actual value.
	// if (!formatting) {
	// 	value = lookup;
	// }

	// // Track used count.
	// let used_counter = variables.__used__[name];
	// variables.__used__[name] = used_counter + 1;
};
