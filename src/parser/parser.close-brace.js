"use strict";

// Get needed modules.
let issue = require("./helper.issue.js");
// Get RegExp patterns.
let { r_nl, r_whitespace } = require("./h.patterns.js");

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
 * @param  {string} string - The line to parse.
 * @return {object} - Object containing parsed information.
 */
module.exports = STATE => {
	require("./helper.trace.js")(STATE); // Trace parser.

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
			// Note: When setting the endpoint make sure to subtract index
			// by 1 so that when it returns to its previous loop is can run
			// the newline character code block.
			NODE.endpoint = STATE.i - 1; // Store newline index.
			STATE.i = STATE.i - 1; // Store newline index.
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
				if (!/[ \t]/.test(char)) {
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
	require("./helper.brace-checks.js")(STATE, NODE, "reset-scope");

	// Add node to tree.
	require("./helper.tree-add.js")(STATE, NODE);

	return NODE;
};
