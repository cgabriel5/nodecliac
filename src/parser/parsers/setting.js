"use strict";

const node = require("../helpers/nodes.js");
const add = require("../helpers/tree-add.js");
const error = require("../helpers/error.js");
const rollback = require("../helpers/rollback.js");
const validate = require("../helpers/validate-value.js");
const { r_nl, r_space, r_letter, r_quote } = require("../helpers/patterns.js");

/**
 * ----------------------------------------------------------- Parsing Breakdown
 * @setting = true
 *         | |    ^-EOL-Whitespace-Boundary 3.
 *         ^-^-Whitespace-Boundary 1/2.
 * ^-Sigil.
 *  ^-Name.
 *          ^-Assignment.
 *            ^-Value.
 * -----------------------------------------------------------------------------
 *
 * @param  {object} S - State object.
 * @return {undefined} - Nothing is returned.
 */
module.exports = S => {
	let { l, text } = S;
	let qchar;
	let state = "sigil";
	let N = node(S, "SETTING");

	for (; S.i < l; S.i++, S.column++) {
		let char = text.charAt(S.i);

		// Stop on a newline char.
		if (r_nl.test(char)) {
			N.end = rollback(S) && S.i;
			break;
		}

		switch (state) {
			case "sigil":
				N.sigil.start = N.sigil.end = S.i;
				state = "name";

				break;

			case "name":
				if (!N.name.value) {
					if (!r_letter.test(char)) error(S, __filename);

					N.name.start = N.name.end = S.i;
					N.name.value += char;
				} else {
					if (/[-_a-zA-Z]/.test(char)) {
						N.name.end = S.i;
						N.name.value += char;
					}
					// Note: If ws char is hit everything after must be ws
					// until an '=' or the end-of-line (newline) char is hit.
					else if (r_space.test(char)) {
						state = "name-wsb";
						continue;
					}
					// If char is an eq sign change state/reset index.
					else if (char === "=") {
						state = "assignment";
						rollback(S);
					} else error(S, __filename);
				}

				break;

			case "name-wsb":
				// Anything but ws or an eq-sign is invalid.
				if (!r_space.test(char)) {
					if (char === "=") {
						state = "assignment";
						rollback(S);
					} else error(S, __filename);
				}

				break;

			case "assignment":
				N.assignment.start = N.assignment.end = S.i;
				N.assignment.value = char;
				state = "value-wsb";

				break;

			case "value-wsb":
				// Once a n-ws char is hit, switch state.
				if (!r_space.test(char)) {
					state = "value";
					rollback(S);
				}

				break;

			case "value":
				if (!N.value.value) {
					if (!/["'a-zA-Z0-9]/.test(char)) error(S, __filename);

					if (r_quote.test(char)) qchar = char;
					N.value.start = N.value.end = S.i;
					N.value.value = char;
				} else {
					if (qchar) {
						let pchar = text.charAt(S.i - 1);

						// Once string closed change state.
						if (char === qchar && pchar !== "\\") state = "eol-wsb";
						N.value.end = S.i;
						N.value.value += char;
					} else {
						// Stop at the first ws char.
						if (r_space.test(char)) {
							state = "eol-wsb";
							rollback(S);
						} else {
							N.value.end = S.i;
							N.value.value += char;
						}
					}
				}

				break;

			case "eol-wsb":
				// Anything but trailing ws is invalid.
				if (!r_space.test(char)) error(S, __filename);

				break;
		}
	}

	validate(S, N);
	add(S, N);
};
