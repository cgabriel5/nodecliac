"use strict";

const node = require("../helpers/nodes.js");
const add = require("../helpers/tree-add.js");
const error = require("../helpers/error.js");
const rollback = require("../helpers/rollback.js");
const validate = require("../helpers/validate-value.js");
const bracechecks = require("../helpers/brace-checks.js");
const { r_nl, r_whitespace } = require("../helpers/patterns.js");

/**
 *  Comment parser.
 *
 * ---------- Parsing Breakdown ------------------------------------------------
 * # Comment body.
 * ^-Symbol (Sigil).
 *  ^-Comment-Chars *(All characters until newline '\n').
 * -----------------------------------------------------------------------------
 *
 * @param  {object} S - Main loop state object.
 * @return {object} - Object containing parsed information.
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
