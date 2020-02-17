"use strict";

const node = require("../helpers/nodes.js");
const add = require("../helpers/tree-add.js");
const rollback = require("../helpers/rollback.js");
const { cin, C_NL } = require("../helpers/patterns.js");

/**
 * ----------------------------------------------------------- Parsing Breakdown
 * # Comment body.
 * ^-Symbol.
 *  ^-Comment-Chars (All chars until newline).
 * -----------------------------------------------------------------------------
 *
 * @param  {object} S - State object.
 * @return {undefined} - Nothing is returned.
 */
module.exports = S => {
	let { l, text } = S;
	let N = node(S, "COMMENT");
	N.comment.start = S.i;

	for (; S.i < l; S.i++, S.column++) {
		let char = text.charAt(S.i);

		if (cin(C_NL, char)) {
			N.end = rollback(S) && S.i;
			break; // Stop at nl char.
		}

		N.comment.end = S.i;
		N.comment.value += char;
	}

	add(S, N);
};
