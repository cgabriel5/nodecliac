"use strict";

// Needed modules.
let issue = require("../helpers/issue.js");
let { r_nl, r_whitespace } = require("../helpers/patterns.js");

/**
 * Parses flag option line.
 *
 * ---------- Parsing States Breakdown -----------------------------------------
 * - value
 *  |     ^-EOL-Whitespace-Boundary 2
 *  ^-Whitespace-Boundary 1
 * ^-Bullet
 *  ^-Value
 * -----------------------------------------------------------------------------
 *
 * @param  {object} STATE - Main loop state object.
 * @return {object} - Object containing parsed information.
 */
module.exports = STATE => {
	// Get global loop state variables.
	let { line, l, string } = STATE;

	// Parsing vars.
	let state = "brace"; // Initial parsing state.
	let warnings = []; // Collect all parsing warnings.
	let end_comsuming;
	let NODE = {
		node: "BRACE",
		brace: { start: null, end: null, value: null },
		line,
		startpoint: STATE.i,
		endpoint: null // Then index at which parsing was ended.
	};

	// Loop over string.
	for (; STATE.i < l; STATE.i++) {
		let char = string.charAt(STATE.i); // Cache current loop item.

		// End loop on a new line char.
		if (r_nl.test(char)) {
			// Note: Subtract index by 1 to run newline character logic code
			// block on next iteration
			NODE.endpoint = --STATE.i; // Store newline index.

			break;
		}

		STATE.column++; // Increment column position.

		switch (state) {
			case "brace":
				// Store ']'/')' brace index positions.
				NODE.brace.start = STATE.i;
				NODE.brace.end = STATE.i;

				// Store brace character.
				NODE.brace.value = char;

				// Set state to collect comment characters.
				state = "eol-wsb";

				break;

			case "eol-wsb":
				if (!r_whitespace.test(char)) {
					// Note: At this point all states have been gone through.
					// All that should remain, if anything, are trailing
					// whitespace Anything other than trailing whitespace is
					// invalid.
					issue.error(STATE);
				}

				break;
		}
	}

	// Note: If a command-chain scope exists, error as scope was never closed.
	require("../helpers/brace-checks.js")(STATE, NODE, "reset-scope");

	// Add node to tree.
	require("../helpers/tree-add.js")(STATE, NODE);

	return NODE;
};
