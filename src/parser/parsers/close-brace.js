"use strict";

const node = require("../helpers/nodes.js");
const add = require("../helpers/tree-add.js");
const error = require("../helpers/error.js");
const rollback = require("../helpers/rollback.js");
const bracechecks = require("../helpers/brace-checks.js");
const { r_nl, r_space } = require("../helpers/patterns.js");

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

		// Stop on a newline char.
		if (r_nl.test(char)) {
			N.end = rollback(S) && S.i;
			break;
		}

		switch (state) {
			case "brace":
				N.brace.start = N.brace.end = S.i;
				N.brace.value = char;
				state = "eol-wsb";

				break;

			case "eol-wsb":
				// Anything but trailing ws is invalid.
				if (!r_space.test(char)) error(S, __filename);
				break;
		}
	}

	// If command-chain scope exists, error as brace wasn't closed.
	bracechecks(S, N, "reset-scope");
	add(S, N);
};
