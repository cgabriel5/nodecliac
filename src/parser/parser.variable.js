"use strict";

// Get needed modules.
// Get RegExp patterns.
let { r_schars, r_nl } = require("./h.patterns.js");
let issue = require("./helper.issue.js");

/**
 * Parses variables line to extract variable name and its value.
 *
 * ---------- Parsing States Breakdown -----------------------------------------
 * $variable = "value"
 *         | |       ^-EOL-Whitespace-Boundary 3
 *         ^-^-Whitespace-Boundary 1/2
 * ^-Symbol (Sigil).
 *  ^-Name.
 *          ^-Assignment.
 *            ^-Value.
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
	let state = "sigil"; // Initial parsing state.
	let qchar;
	let warnings = []; // Collect all parsing warnings.
	let DATA = {
		node: "VARIABLE",
		sigil: { start: null, end: null },
		name: { start: null, end: null, value: null },
		assignment: { start: null, end: null, value: null },
		value: { start: null, end: null, value: null },
		// wsb: { start: null, end: null },
		line,
		startpoint: STATE.i,
		endpoint: null // Then index at which parsing was ended.
	};

	// Loop over string.
	for (; STATE.i < l; STATE.i++) {
		let char = string.charAt(STATE.i); // Cache current loop item.

		// End loop on a new line char.
		if (r_nl.test(char)) {
			// Note: When setting the endpoint make sure to subtract index
			// by 1 so that when it returns to its previous loop is can run
			// the newline character code block.
			DATA.endpoint = STATE.i - 1; // Store newline index.
			STATE.i = STATE.i - 1; // Store newline index.
			break;
		}

		STATE.column++; // Increment column position.

		switch (state) {
			case "sigil":
				// Store '$' sigil index positions.
				DATA.sigil.start = STATE.i;
				DATA.sigil.end = STATE.i;

				// Now start looking for setting name.
				state = "name";

				break;

			case "name":
				// If the name value is empty check for first letter of setting.
				if (!DATA.name.value) {
					// Name must start with a letter.
					if (!/[a-zA-Z]/.test(char)) {
						// [TODO]: Specify Error: Setting must start with a letter.
						issue.error(STATE, 0, __filename);
					}

					// Set name index positions.
					DATA.name.start = STATE.i;
					DATA.name.end = STATE.i;

					// Start building setting name string.
					DATA.name.value = char;

					// Continue building setting name string.
				} else {
					// If char is allowed keep building string.
					if (/[-_a-zA-Z]/.test(char)) {
						// Set name index positions.
						DATA.name.end = STATE.i;
						// Continue building setting name string.
						DATA.name.value += char;

						// If we encounter a whitespace character, everything
						// after this point must be a space until we encounter
						// an eq sign or the end-of-line (newline) character.
					} else if (/[ \t]/.test(char)) {
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
						issue.error(STATE, 0, __filename);
					}
				}

				break;

			case "name-wsb":
				// At this point we are looking for the assignment operator.
				// Anything but whitespace or an eq-sign are invalid chars.
				if (!/[ \t]/.test(char)) {
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
						issue.error(STATE, 0, __filename);
					}
				}

				break;

			case "assignment":
				// Store index positions.
				DATA.assignment.start = STATE.i;
				DATA.assignment.end = STATE.i;
				// Store assignment character.
				DATA.assignment.value = char;

				// Change state to look for any space post assignment but
				// before the actual setting's value.
				state = "value-wsb";

				break;

			case "value-wsb":
				// Ignore consecutive whitespace. Once a non-whitespace
				// character is hit, switch to value state.
				if (!/[ \t]/.test(char)) {
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
				if (!DATA.value.value) {
					// Character must be one of the following:
					if (!/["'a-zA-Z0-9]/.test(char)) {
						// Note: Hitting this block means an invalid
						// character was encountered so give an error.
						issue.error(STATE, 0, __filename);
					}

					// Check if character is a quote.
					if (/["']/.test(char)) {
						qchar = char;
					}

					// Store index positions.
					DATA.value.start = STATE.i;
					DATA.value.end = STATE.i;
					// Start building the value string.
					DATA.value.value = char;

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
						// 	DATA.value.value += res.variable.value;
						// } else {
						// Store index positions.
						DATA.value.end = STATE.i;
						// Continue building the value string.
						DATA.value.value += char;
						// }

						// Not quoted.
					} else {
						// We must stop at the first space char.
						if (/[ \t]/.test(char)) {
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
							DATA.value.end = STATE.i;
							// Continue building the value string.
							DATA.value.value += char;
						}
					}
				}

				break;

			case "eol-wsb":
				if (!/[ \t]/.test(char)) {
					// Note: At this point all states have been gone through.
					// All that should remain, if anything, are trailing
					// whitespace Anything other than trailing whitespace is
					// invalid.
					issue.error(STATE, 0, __filename);
				}

				break;
		}
	}

	// Validate extracted variable value.
	require("./helper.validate-value.js")(DATA, STATE);

	// Add node to tree.
	require("./helper.tree-add.js")(STATE, DATA);

	// [TODO] Add following variable checks later on.

	// Check for dangling '$'.
	// if (name === "$") {}

	// If assignment but not value give warning.
	// if (assignment && !value) {}

	// If no value was provided give warning.
	// if (!assignment) {}

	// If variable exists give an dupe/override warning.
	// if (variables.hasOwnProperty(name)) {}

	// Finally unquote value.
	// [https://stackoverflow.com/a/21873245]
	let value = DATA.value.value;
	value = value.substring(1, value.length - 1);
	// Unquote value. [https://stackoverflow.com/a/19156197]
	// 	value = value.replace(/^(["'])(.+(?=\1$))\1$/, "$2");

	// Store where variable was declared.
	STATE.DB.variables[DATA.name.value] = value;

	return DATA;
};
