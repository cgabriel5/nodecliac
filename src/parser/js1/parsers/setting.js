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
	C_SET_IDENT,
	C_SET_VALUE
} = require("../helpers/charsets.js");

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
module.exports = (S) => {
	let l = S.l;
	let qchar;
	let state = "sigil";
	let N = node(nk.Setting, S);

	let c,
		p = "";
	for (; S.i < l; S.i++, S.column++) {
		p = c;
		c = S.text.charAt(S.i);

		if (cin(C_NL, c)) {
			N.end = rollback(S) && S.i;
			break; // Stop at nl char.
		}

		if (c === "#" && p !== "\\" && state !== "value") {
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
					if (cnotin(C_LETTERS, c)) error(S);

					N.name.start = N.name.end = S.i;
					N.name.value = c;
				} else {
					if (cin(C_SET_IDENT, c)) {
						N.name.end = S.i;
						N.name.value += c;
					} else if (cin(C_SPACES, c)) {
						state = "name-wsb";
						continue;
					} else if (c === "=") {
						state = "assignment";
						rollback(S);
					} else error(S);
				}

				break;

			case "name-wsb":
				if (cnotin(C_SPACES, c)) {
					if (c === "=") {
						state = "assignment";
						rollback(S);
					} else error(S);
				}

				break;

			case "assignment":
				N.assignment.start = N.assignment.end = S.i;
				N.assignment.value = c;
				state = "value-wsb";

				break;

			case "value-wsb":
				if (cnotin(C_SPACES, c)) {
					state = "value";
					rollback(S);
				}

				break;

			case "value":
				if (!N.value.value) {
					if (cnotin(C_SET_VALUE, c)) error(S);

					if (cin(C_QUOTES, c)) qchar = c;
					N.value.start = N.value.end = S.i;
					N.value.value = c;
				} else {
					if (qchar) {
						if (c === qchar && p !== "\\") state = "eol-wsb";
						N.value.end = S.i;
						N.value.value += c;
					} else {
						if (cin(C_SPACES, c) && p !== "\\") {
							state = "eol-wsb";
							rollback(S);
						} else {
							N.value.end = S.i;
							N.value.value += c;
						}
					}
				}

				break;

			case "eol-wsb":
				if (cnotin(C_SPACES, c)) error(S);

				break;
		}
	}

	validate(S, N);
	add(S, N);

	// Store test.
	if (N.name.value === "test") S.tests.push(N.value.value);
};
