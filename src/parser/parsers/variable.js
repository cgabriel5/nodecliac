"use strict";

const node = require("../helpers/nodes.js");
const error = require("../helpers/error.js");
const add = require("../helpers/tree-add.js");
const { nk } = require("../helpers/enums.js");
const rollback = require("../helpers/rollback.js");
const validate = require("../helpers/validate.js");
const {
	cin,
	cnotin,
	C_NL,
	C_SPACES,
	C_LETTERS,
	C_QUOTES,
	C_VAR_IDENT,
	C_VAR_VALUE
} = require("../helpers/charsets.js");

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
module.exports = (S) => {
	let l = S.l;
	let qchar;
	let state = "sigil";
	let N = node(nk.Variable, S);

	let char,
		pchar = "";
	for (; S.i < l; S.i++, S.column++) {
		pchar = char;
		char = S.text.charAt(S.i);

		if (cin(C_NL, char)) {
			N.end = rollback(S) && S.i;
			break; // Stop at nl char.
		}

		if (char === "#" && pchar !== "\\" && state !== "value") {
			rollback(S);
			N.end = S.i;
			break;
		}

		switch (state) {
			case "sigil":
				N.sigil.start = N.sigil.end = S.i;
				state = "name";

				break;

			case "name":
				if (!N.name.value) {
					if (cnotin(C_LETTERS, char)) error(S);

					N.name.start = N.name.end = S.i;
					N.name.value = char;
				} else {
					if (cin(C_VAR_IDENT, char)) {
						N.name.end = S.i;
						N.name.value += char;
					} else if (cin(C_SPACES, char)) {
						state = "name-wsb";
						continue;
					} else if (char === "=") {
						state = "assignment";
						rollback(S);
					} else error(S);
				}

				break;

			case "name-wsb":
				if (cnotin(C_SPACES, char)) {
					if (char === "=") {
						state = "assignment";
						rollback(S);
					} else error(S);
				}

				break;

			case "assignment":
				N.assignment.start = N.assignment.end = S.i;
				N.assignment.value = char;
				state = "value-wsb";

				break;

			case "value-wsb":
				if (cnotin(C_SPACES, char)) {
					state = "value";
					rollback(S);
				}

				break;

			case "value":
				if (!N.value.value) {
					if (cnotin(C_VAR_VALUE, char)) error(S);

					if (cin(C_QUOTES, char)) qchar = char;
					N.value.start = N.value.end = S.i;
					N.value.value = char;
				} else {
					if (qchar) {
						if (char === qchar && pchar !== "\\") state = "eol-wsb";
						N.value.end = S.i;
						N.value.value += char;
					} else {
						if (cin(C_SPACES, char) && pchar !== "\\") {
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
				if (cnotin(C_SPACES, char)) error(S);

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
