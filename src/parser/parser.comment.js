"use strict";

// // Get needed modules.
// const issuefunc = require("./p.error.js");
// Get RegExp patterns.
let { r_nl, r_whitespace } = require("./h.patterns.js");
let issue = require("./helper.issue.js");

/**
 * Parses comment lines.
 *
 * ---------- Parsing States Breakdown -----------------------------------------
 * # Some comment.
 * ^-Symbol (Sigil).
 *  ^-Whitespace-Boundary (Space/Tab - At least 1 after the symbol).
 *   ^-Comment-Char *(All characters until newline '\n').
 * -----------------------------------------------------------------------------
 *
 * @param  {object} object - Main loop state object.
 * @return {object} - Object containing parsed information.
 */
module.exports = STATE => {
	// require("./h.trace.js")(__filename); // Trace parser.

	// Get global loop state variables.
	let { line, column, i, l, string } = STATE;

	// Parsing vars.
	let state = "sigil"; // Initial parsing state.
	let warnings = []; // Collect all parsing warnings.
	let DATA = {
		node: "COMMENT",
		sigil: { start: null, end: null },
		wsb: { start: null, end: null },
		comment: { start: null, end: null, value: "" },
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
			DATA.endpoint = STATE.i - 1; // Store newline index.
			STATE.i = STATE.i - 1; // Store newline index.
			break;
		}

		STATE.column++; // Increment column position.

		// Default parse state.
		switch (state) {
			case "sigil":
				// Store '#' sigil index positions.
				DATA.sigil.start = STATE.i;
				DATA.sigil.end = STATE.i;

				// Change state to whitespace-boundary after sigil.
				state = "wsb-sigil";

				break;

			case "wsb-sigil":
				// Character must be a whitespace (space or tab) character
				// else give an error for an invalid character.
				if (!r_whitespace.test(char)) {
					issue.error(STATE, 0, __filename);
				}

				// Else, it's valid so store positions.
				DATA.wsb.start = STATE.i;
				DATA.wsb.end = STATE.i;

				// Set state to collect comment characters.
				state = "comment";

				break;

			case "comment":
				// Store comment index positions.
				// Store start index if not already stored.
				if (!DATA.comment.start) {
					DATA.comment.start = STATE.i;
				}
				DATA.comment.end = STATE.i;

				break;
		}

		// Allow for any characters in comments.
		DATA.comment.string += char;
	}

	// console.log(DATA);
	// console.log();
	return;
	return DATA;
};
