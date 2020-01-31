"use strict";

const node = require("../helpers/nodes.js");
const add = require("../helpers/tree-add.js");
const error = require("../helpers/error.js");
const rollback = require("../helpers/rollback.js");
const validate = require("../helpers/validate.js");
const { r_nl, r_space, r_letter, r_quote } = require("../helpers/patterns.js");

/**
 * ----------------------------------------------------------- Parsing Breakdown
 * $variable = "value"
 *          | |       ^-EOL-Whitespace-Boundary 3.
 *          ^-^-Whitespace-Boundary 1/2.
 * ^-Sigil.
 *  ^-Name.
 *           ^-Assignment.
 *             ^-Value.
 * -----------------------------------------------------------------------------
 *
 * @param  {object} S - State object.
 * @return {undefined} - Nothing is returned.
 */
module.exports = S => {
	let { l, text } = S;
	let qchar;
	let state = "sigil";
	let N = node(S, "VARIABLE");

	for (; S.i < l; S.i++, S.column++) {
		let char = text.charAt(S.i);

		if (r_nl.test(char)) {
			N.end = rollback(S) && S.i;
			break; // Stop at nl char.
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
					N.name.value = char;
				} else {
					if (/[-_a-zA-Z]/.test(char)) {
						N.name.end = S.i;
						N.name.value += char;
					} else if (r_space.test(char)) {
						state = "name-wsb";
						continue;
					} else if (char === "=") {
						state = "assignment";
						rollback(S);
					} else error(S, __filename);
				}

				break;

			case "name-wsb":
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

						if (char === qchar && pchar !== "\\") state = "eol-wsb";
						N.value.end = S.i;
						N.value.value += char;
					} else {
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
				if (!r_space.test(char)) error(S, __filename);

				break;
		}
	}

	validate(S, N);
	add(S, N);

	let value = N.value.value || "";
	value = value.substring(1, value.length - 1);
	// Unquote value. [https://stackoverflow.com/a/21873245]
	// Unquote value. [https://stackoverflow.com/a/19156197]
	// value = value.replace(/^(["'])(.+(?=\1$))\1$/, "$2");

	S.tables.variables[N.name.value] = value; // Store var/val.
};
