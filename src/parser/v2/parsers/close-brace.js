"use strict";

const add = require("../helpers/tree-add.js");
const error = require("../helpers/error.js");
const bracechecks = require("../helpers/brace-checks.js");
const { r_nl, r_whitespace } = require("../helpers/patterns.js");

/**
 * Closing-brace parser.
 *
 * ---------- Parsing Breakdown ------------------------------------------------
 * - value
 *  |     ^-EOL-Whitespace-Boundary 2
 *  ^-Whitespace-Boundary 1
 * ^-Bullet
 *   ^-Value
 * -----------------------------------------------------------------------------
 *
 * @param  {object} S - Main loop state object.
 * @return {object} - Object containing parsed information.
 */
module.exports = S => {
	let { line, l, text } = S;

	// Parsing vars.
	let state = "brace"; // Initial parsing state.
	let NODE = {
		node: "BRACE",
		brace: { start: null, end: null, value: null },
		line,
		startpoint: S.i,
		endpoint: null // Index where parsing ended.
	};

	// Loop over string.
	for (; S.i < l; S.i++) {
		let char = text.charAt(S.i); // Cache current loop char.

		// End loop on a newline char.
		if (r_nl.test(char)) {
			NODE.endpoint = --S.i; // Rollback (run '\n' parser next).

			break;
		}

		S.column++; // Increment column position.

		switch (state) {
			case "brace":
				// Store index positions.
				NODE.brace.start = S.i;
				NODE.brace.end = S.i;
				NODE.brace.value = char; // Store character.

				state = "eol-wsb"; // Reset parsing state.

				break;

			case "eol-wsb":
				// Anything but trailing whitespace is invalid so give error.
				if (!r_whitespace.test(char)) error(S, __filename);

				break;
		}
	}

	// Note: If command-chain scope exists, error as brace wasn't closed.
	bracechecks(S, NODE, "reset-scope");
	add(S, NODE); // Add node to tree.
};
