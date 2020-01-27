"use strict";

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
 * @param  {object} STATE - Main loop state object.
 * @return {object} - Object containing parsed information.
 */
module.exports = STATE => {
	let { line, l, text } = STATE;

	// Parsing vars.
	let state = "sigil"; // Initial parsing state.
	let NODE = {
		node: "COMMENT",
		sigil: { start: null, end: null },
		comment: { start: null, end: null, value: "" },
		line,
		startpoint: STATE.i,
		endpoint: null // Index where parsing ended.
	};

	// Loop over string.
	for (; STATE.i < l; STATE.i++) {
		let char = text.charAt(STATE.i); // Cache current loop char.

		// End loop on a newline char.
		if (r_nl.test(char)) {
			NODE.endpoint = --STATE.i; // Rollback (run '\n' parser next).

			break;
		}

		STATE.column++; // Increment column position.

		switch (state) {
			case "sigil":
				// Store index positions.
				NODE.sigil.start = STATE.i;
				NODE.sigil.end = STATE.i;

				state = "comment"; // Reset parsing state.

				break;

			case "comment":
				// Note: Ensure start index is stored if not already.
				if (!NODE.comment.start) NODE.comment.start = NODE.sigil.start;
				NODE.comment.end = STATE.i; // Store index positions.

				break;
		}

		NODE.comment.value += char; // Capture all comment characters.
	}

	add(STATE, NODE); // Add node to tree.
};
