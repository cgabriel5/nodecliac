"use strict";

const node = require("../helpers/nodes.js");
const error = require("../helpers/error.js");
const add = require("../helpers/tree-add.js");
const { nk } = require("../helpers/enums.js");
const rollback = require("../helpers/rollback.js");
const bracechecks = require("../helpers/brace-checks.js");
const { cin, cnotin, C_NL, C_SPACES } = require("../helpers/charsets.js");

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
module.exports = (S) => {
	let l = S.l;
	let state = "brace";
	let N = node(nk.Brace, S);

	let c,
		p = "";
	for (; S.i < l; S.i++, S.column++) {
		p = c;
		c = S.text.charAt(S.i);

		if (cin(C_NL, c)) {
			N.end = rollback(S) && S.i;
			break; // Stop at nl char.
		}

		if (c === "#" && p !== "\\") {
			rollback(S);
			N.end = S.i;
			break;
		}

		switch (state) {
			case "brace":
				N.brace.start = N.brace.end = S.i;
				N.brace.value = c;
				state = "eol-wsb";

				break;

			case "eol-wsb":
				if (cnotin(C_SPACES, c)) error(S);
				break;
		}
	}

	// Error if cc scope exists (brace not closed).
	bracechecks(S, N, "reset-scope");
	add(S, N);
};
