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
 * Setting parser.
 *
 * ---------- Parsing Breakdown ------------------------------------------------
 * @setting = true
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
	let { line, l, text } = STATE;

	// Parsing vars.
	let state = "sigil"; // Initial parsing state.
	let qchar;
	let NODE = {
		node: "SETTING",
		sigil: { start: null, end: null },
		name: { start: null, end: null, value: "" },
		assignment: { start: null, end: null, value: null },
		value: { start: null, end: null, value: null },
		line,
		startpoint: STATE.i,
		endpoint: null // Index where parsing ended.
	};

	// Loop over string.
	for (; STATE.i < l; STATE.i++) {
		let char = text.charAt(STATE.i); // Cache current loop char.

		// End loop on a newline char.
		if (r_nl.test(char)) {
			// Rollback to run newline char code block next iteration.
			NODE.endpoint = --STATE.i; // Store newline index.

			break;
		}

		STATE.column++; // Increment column position.

		switch (state) {
			case "sigil":
				// Store index positions.
				NODE.sigil.start = STATE.i;
				NODE.sigil.end = STATE.i;

				state = "name"; // Reset parsing state.

				break;

			case "name":
				// If name is empty check for first letter.
				if (!NODE.name.value) {
					// Name must start with pattern else give error.
					if (!r_letter.test(char)) error(STATE, __filename);

					// Set index positions.
					NODE.name.start = STATE.i;
					NODE.name.end = STATE.i;

					NODE.name.value += char; // Start building string.
				}
				// Else continue building string.
				else {
					// If char is allowed keep building string.
					if (/[-_a-zA-Z]/.test(char)) {
						// Set index positions.
						NODE.name.end = STATE.i;
						NODE.name.value += char; // Continue building string.
					}
					// Note: If a whitespace character is encountered
					// everything after this point must be a space
					// until an eq sign or the end-of-line (newline)
					// character is encountered.
					else if (r_whitespace.test(char)) {
						state = "name-wsb";
						continue;
					}
					// If char is an eq sign change state/reset index.
					else if (char === "=") {
						state = "assignment";

						rollback(STATE); // Rollback loop index.
					}
					// Note: Anything at this point is an invalid char.
					else error(STATE, __filename);
				}

				break;

			case "name-wsb":
				// This state looks for the assignment operator. Anything
				// but whitespace or an eq-sign are invalid chars.
				if (!r_whitespace.test(char)) {
					if (char === "=") {
						state = "assignment"; // Reset parsing state.

						rollback(STATE); // Rollback loop index.
					}
					// Note: Anything at this point is an invalid char.
					else error(STATE, __filename);
				}

				break;

			case "assignment":
				// Store index positions.
				NODE.assignment.start = STATE.i;
				NODE.assignment.end = STATE.i;
				NODE.assignment.value = char; // Store character.

				state = "value-wsb"; // Reset parsing state.

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
				// If first char, only `"`, `'`, or `a-zA-Z0-9` are allowed.
				if (!NODE.value.value) {
					// If char is not allowed give an error.
					if (!/["'a-zA-Z0-9]/.test(char)) error(STATE, __filename);

					if (r_quote.test(char)) qchar = char; // Store if a quote char.

					// Store index positions.
					NODE.value.start = STATE.i;
					NODE.value.end = STATE.i;
					NODE.value.value = char; // Start building string.
				}
				// Continue building string.
				else {
					// If value is a quoted string allow for anything
					// and end at the same style-unescaped quote.
					if (qchar) {
						let pchar = text.charAt(STATE.i - 1); // Previous char.

						// Once quoted string is closed change state.
						if (char === qchar && pchar !== "\\") state = "eol-wsb";

						// Store index positions.
						NODE.value.end = STATE.i;
						NODE.value.value += char; // Continue building string.
					}
					// Else, not quoted.
					else {
						// Must stop at the first space char.
						if (r_whitespace.test(char)) {
							state = "eol-wsb";

							rollback(STATE); // Rollback loop index.
						} else {
							// Store index positions.
							NODE.value.end = STATE.i;
							NODE.value.value += char; // Continue building string.
						}
					}
				}

				break;

			case "eol-wsb":
				// Anything but trailing whitespace is invalid so give error.
				if (!r_whitespace.test(char)) error(STATE, __filename);

				break;
		}
	}

	validate(STATE, NODE); // Validate extracted variable value.
	add(STATE, NODE); // Add node to tree.
};
