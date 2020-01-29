"use strict";

const node = require("../helpers/nodes.js");
const add = require("../helpers/tree-add.js");
const rollback = require("../helpers/rollback.js");
const { r_nl } = require("../helpers/patterns.js");

/**
 * ----------------------------------------------------------- Parsing Breakdown
 * # Comment body.
 * ^-Sigil.
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

		// Stop on a newline char.
		if (r_nl.test(char)) {
			N.end = rollback(S) && S.i;
			break;
		}

		N.comment.end = S.i;
		N.comment.value += char;
	}

	add(S, N);
};
