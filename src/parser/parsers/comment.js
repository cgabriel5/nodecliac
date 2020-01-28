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
	let { line, l, text } = S;
	let state = "sigil";
	let N = node(S, "COMMENT");

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

				state = "comment"; // Reset parsing state.

				break;

			case "comment":
				// Note: Ensure start index is stored if not already.
				if (!N.comment.start) N.comment.start = N.sigil.start;
				N.comment.end = S.i; // Store index positions.

				break;
		}

		N.comment.value += char; // Capture all comment characters.
	}

	add(S, N); // Add node to tree.
};
