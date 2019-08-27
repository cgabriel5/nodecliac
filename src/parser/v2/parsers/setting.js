"use strict";

// Needed modules.
let issue = require("../helpers/issue.js");
let {
	r_nl,
	r_whitespace,
	r_letter,
	r_quote
} = require("../helpers/patterns.js");

/**
 * Parses settings line to extract setting name and its value.
 *
 * ---------- Parsing States Breakdown -----------------------------------------
 * @default = true
 *         | |    ^-EOL-Whitespace-Boundary 3.
 *         ^-^-Whitespace-Boundary 1/2.
 * ^-Symbol (Sigil).
 *  ^-Name.
 *          ^-Assignment.
 *            ^-Value.
 * -----------------------------------------------------------------------------
 *
 * @param  {object} STATE - Main loop state object.
 * @return {object} - Object containing parsed information.
 */
module.exports = STATE => {
	// Get global loop state variables.
	let { line, l, string } = STATE;

	// Parsing vars.
	let state = "sigil"; // Initial parsing state.
	let qchar;
	let warnings = []; // Collect all parsing warnings.
	let NODE = {
		node: "SETTING",
		sigil: { start: null, end: null },
		name: { start: null, end: null, value: "" },
		assignment: { start: null, end: null, value: null },
		value: { start: null, end: null, value: null },
		line,
		startpoint: STATE.i,
		endpoint: null // Then index at which parsing was ended.
	};

	// Loop over string.
	for (; STATE.i < l; STATE.i++) {
		let char = string.charAt(STATE.i); // Cache current loop item.

		// End loop on a new line char.
		if (r_nl.test(char)) {
			// Note: Subtract index by 1 to run newline character logic code
			// block on next iteration
			NODE.endpoint = --STATE.i; // Store newline index.

			break;
		}

		STATE.column++; // Increment column position.

		switch (state) {
			case "sigil":
				// Store '#' sigil index positions.
				NODE.sigil.start = STATE.i;
				NODE.sigil.end = STATE.i;

				// Now start looking for setting name.
				state = "name";

				break;

			case "name":
				// If the name value is empty check for first letter of setting.
				if (!NODE.name.value) {
					// Name must start with a letter.
					if (!r_letter.test(char)) {
						// Note: Setting must start with a letter.
						issue.error(STATE);
					}

					// Set name index positions.
					NODE.name.start = STATE.i;
					NODE.name.end = STATE.i;

					// Start building setting name string.
					NODE.name.value += char;

					// Continue building setting name string.
				} else {
					// If char is allowed keep building string.
					if (/[-_a-zA-Z]/.test(char)) {
						// Set name index positions.
						NODE.name.end = STATE.i;
						// Continue building setting name string.
						NODE.name.value += char;

						// If we encounter a whitespace character, everything
						// after this point must be a space until we encounter
						// an eq sign or the end-of-line (newline) character.
					} else if (r_whitespace.test(char)) {
						state = "name-wsb";
						continue;

						// If char is an eq sign change state/reset index.
					} else if (char === "=") {
						state = "assignment";

						// Note: Rollback index by 1 to allow parser to
						// start at assignment case on next iteration.
						STATE.i -= 1;
						STATE.column--;

						// Anything else the character is not allowed.
					} else {
						// Note: Hitting this block means an invalid
						// character was encountered so give an error.
						issue.error(STATE);
					}
				}

				break;

			case "name-wsb":
				// At this point we are looking for the assignment operator.
				// Anything but whitespace or an eq-sign are invalid chars.
				if (!r_whitespace.test(char)) {
					if (char === "=") {
						// Change sate to assignment.
						state = "assignment";

						// Note: Rollback index by 1 to allow parser to
						// start at assignment case on next iteration.
						STATE.i -= 1;
						STATE.column--;
					} else {
						// Note: Hitting this block means an invalid
						// character was encountered so give an error.
						issue.error(STATE);
					}
				}

				break;

			case "assignment":
				// Store index positions.
				NODE.assignment.start = STATE.i;
				NODE.assignment.end = STATE.i;
				// Store assignment character.
				NODE.assignment.value = char;

				// Change state to look for any space post assignment but
				// before the actual setting's value.
				state = "value-wsb";

				break;

			case "value-wsb":
				// Ignore consecutive whitespace. Once a non-whitespace
				// character is hit, switch to value state.
				if (!r_whitespace.test(char)) {
					state = "value";

					// Note: Rollback index by 1 to allow parser to
					// start at assignment case on next iteration.
					STATE.i -= 1;
					STATE.column--;
				}

				break;

			case "value":
				// If this is the first char is must be either one of the
				// following: ", ', or a-zA-Z0-9.
				if (!NODE.value.value) {
					// Character must be one of the following:
					if (!/["'a-zA-Z0-9]/.test(char)) {
						// Note: Hitting this block means an invalid
						// character was encountered so give an error.
						issue.error(STATE);
					}

					// Check if character is a quote.
					if (r_quote.test(char)) {
						qchar = char;
					}

					// Store index positions.
					NODE.value.start = STATE.i;
					NODE.value.end = STATE.i;
					// Start building the value string.
					NODE.value.value = char;

					// Continue building setting's value string.
				} else {
					// If value is a quoted string we allow for anything.
					// String is ended at the same style-unescaped quote.
					if (qchar) {
						// Get previous character.
						let pchar = string.charAt(STATE.i - 1);
						let nchar = string.charAt(STATE.i + 1);

						// Once quoted string is closed change state.
						if (char === qchar && pchar !== "\\") {
							state = "eol-wsb";
						}

						// // Check for template strings (variables).
						// if (char === "$" && pchar !== "\\" && nchar === "{") {
						// 	// Note: Reduce column counter by 1 since parser loop will
						// 	// commence at the start of the first non whitespace char.
						// 	// A char that has already been looped over in the main loop.
						// 	STATE.column--;

						// 	// Store result in variable to access the
						// 	// interpolated variable's value.
						// 	let res = p_tstring(STATE); // Run template-string parser...
						// 	// Add interpolated value to string.
						// 	NODE.value.value += res.variable.value;
						// } else {
						// Store index positions.
						NODE.value.end = STATE.i;
						// Continue building the value string.
						NODE.value.value += char;
						// }

						// Not quoted.
					} else {
						// We must stop at the first space char.
						if (r_whitespace.test(char)) {
							state = "eol-wsb";

							// Note: Rollback index by 1 to allow parser to
							// start at assignment case on next iteration.
							STATE.i -= 1;
							STATE.column--;
						} else {
							// // When building unquoted "strings" warn user
							// // when using unescaped special characters.
							// if (r_schars.test(char)) {
							// 	issue("warning", 5, char);
							// }

							// Store index positions.
							NODE.value.end = STATE.i;
							// Continue building the value string.
							NODE.value.value += char;
						}
					}
				}

				break;

			case "eol-wsb":
				if (!r_whitespace.test(char)) {
					// Note: At this point all states have been gone through.
					// All that should remain, if anything, are trailing
					// whitespace Anything other than trailing whitespace is
					// invalid.
					issue.error(STATE);
				}

				break;
		}
	}

	// Validate extracted variable value.
	require("../helpers/validate-value.js")(STATE, NODE);

	// Add node to tree.
	require("../helpers/tree-add.js")(STATE, NODE);

	return NODE;

	// Check for dangling '@'.
	// if (name === "@") {}

	// If assignment but not value give warning.
	// if (assignment && !value) {}

	// If no value was provided give warning.
	// if (!assignment) {}

	// If setting exists give an dupe/override warning.
	// if (settings.hasOwnProperty(name)) {}
};
