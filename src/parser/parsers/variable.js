"use strict";

const node = require("../helpers/nodes.js");
const add = require("../helpers/tree-add.js");
const error = require("../helpers/error.js");
const rollback = require("../helpers/rollback.js");
const validate = require("../helpers/validate-value.js");
const bracechecks = require("../helpers/brace-checks.js");

/**
 * Variable parser.
 *
 * ---------- Parsing Breakdown ------------------------------------------------
 * $variable = "value"
 *          | |       ^-EOL-Whitespace-Boundary 3.
 *          ^-^-Whitespace-Boundary 1/2.
 * ^-Symbol (Sigil).
 *  ^-Name.
 *           ^-Assignment.
 *             ^-Value.
 * -----------------------------------------------------------------------------
 *
 * @param  {object} S - Main loop state object.
 * @return {object} - Object containing parsed information.
 */
module.exports = S => {
	let { line, l, text } = S;
	let qchar;
	let state = "sigil";
	let N = node(S, "VARIABLE");

	// Loop over string.
	for (; S.i < l; S.i++) {
		let char = text.charAt(S.i); // Cache current loop char.

		// End loop on a newline char.
		if (r_nl.test(char)) {
			N.endpoint = --S.i; // Rollback (run '\n' parser next).

			break;
		}

		S.column++; // Increment column position.

		switch (state) {
			case "sigil":
				// Store index positions.
				N.sigil.start = S.i;
				N.sigil.end = S.i;

				state = "name"; // Reset parsing state.

				break;

			case "name":
				// If name value is empty check for first letter.
				if (!N.name.value) {
					// Name must start with pattern else give error.
					if (!r_letter.test(char)) error(S, __filename);

					// Set index positions.
					N.name.start = S.i;
					N.name.end = S.i;

					N.name.value = char; // Start building string.
				}
				// Else continue building string.
				else {
					// If char is allowed keep building string.
					if (/[-_a-zA-Z]/.test(char)) {
						// Set index positions.
						N.name.end = S.i;
						N.name.value += char; // Continue building string.
					}
					// Note: If a whitespace character is encountered
					// everything after this point must be a space
					// until an eq sign or the end-of-line (newline)
					// character is encountered.
					else if (r_space.test(char)) {
						state = "name-wsb";
						continue;
					}
					// If char is an eq sign change state/reset index.
					else if (char === "=") {
						state = "assignment";

						rollback(S); // Rollback loop index.
					}
					// Note: Anything at this point is an invalid char.
					else error(S, __filename);
				}

				break;

			case "name-wsb":
				// This state looks for the assignment operator. Anything
				// but whitespace or an eq-sign are invalid chars.
				if (!r_space.test(char)) {
					if (char === "=") {
						state = "assignment"; // Reset parsing state.

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

			case "value-wsb":
				// Ignore consecutive whitespace. Once a non-whitespace
				// character is hit, switch to value state.
				if (!r_space.test(char)) {
					state = "value";

					rollback(S); // Rollback loop index.
				}

				break;

			case "value":
				// If first char, only `"`, `'`, or `a-zA-Z0-9` are allowed.
				if (!N.value.value) {
					// If char is not allowed give an error.
					if (!/["'a-zA-Z0-9]/.test(char)) error(S, __filename);

					if (r_quote.test(char)) qchar = char; // Store if a quote char.

					// Store index positions.
					N.value.start = S.i;
					N.value.end = S.i;
					N.value.value = char; // Start building string.
				}
				// Continue building string.
				else {
					// If value is a quoted string allow for anything
					// and end at the same style-unescaped quote.
					if (qchar) {
						let pchar = text.charAt(S.i - 1); // Previous char.

						// Once quoted string is closed change state.
						if (char === qchar && pchar !== "\\") state = "eol-wsb";

						// Store index positions.
						N.value.end = S.i;
						N.value.value += char; // Continue building string.
					}
					// Else, not quoted.
					else {
						// Must stop at the first space char.
						if (r_space.test(char)) {
							state = "eol-wsb";

							rollback(S); // Rollback loop index.
						} else {
							// Store index positions.
							N.value.end = S.i;
							N.value.value += char; // Continue building string.
						}
					}
				}

				break;

			case "eol-wsb":
				// Anything but trailing whitespace is invalid so give error.
				if (!r_space.test(char)) error(S, __filename);

				break;
		}
	}

	validate(S, N); // Validate extracted variable value.
	add(S, N); // Add node to tree.

	// Unquote value. [https://stackoverflow.com/a/21873245]
	let value = N.value.value || "";
	value = value.substring(1, value.length - 1);
	// Unquote value. [https://stackoverflow.com/a/19156197]
	// value = value.replace(/^(["'])(.+(?=\1$))\1$/, "$2");

	S.tables.variables[N.name.value] = value; // Store var and its value.
};
