"use strict";

const node = require("../helpers/nodes.js");
const add = require("../helpers/tree-add.js");
const error = require("../helpers/error.js");
const rollback = require("../helpers/rollback.js");
const bracechecks = require("../helpers/brace-checks.js");
const { cin, cnotin, C_NL, C_SPACES } = require("../helpers/patterns.js");

/**
 * ----------------------------------------------------------- Parsing Breakdown
 * - value
 *  |     ^-EOL-Whitespace-Boundary 2
 *  ^-Whitespace-Boundary 1
 * ^-Bullet
 *   ^-Value
 * -----------------------------------------------------------------------------
 *
 * @param  {object} S - State object.
 * @return {undefined} - Nothing is returned.
 */
module.exports = S => {
	let { l, text } = S;
	let state = "brace";
	let N = node(S, "BRACE");

	for (; S.i < l; S.i++, S.column++) {
		let char = text.charAt(S.i);

		if (cin(C_NL, char)) {
			N.end = rollback(S) && S.i;
			break; // Stop at nl char.
		}

		switch (state) {
			case "brace":
				N.brace.start = N.brace.end = S.i;
				N.brace.value = char;
				state = "eol-wsb";

				break;

			case "eol-wsb":
				if (cnotin(C_SPACES, char)) error(S, __filename);
				break;
		}
	}

	// Error if cc scope exists (brace not closed).
	bracechecks(S, N, "reset-scope");
	add(S, N);
};
