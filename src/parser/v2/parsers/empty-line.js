"use strict";

/**
 * Add new line node to tree.
 *
 * ---------- Parsing States Breakdown -----------------------------------------
 * \n Some body.
 * ^-New-line character.
 * -----------------------------------------------------------------------------
 *
 * @param  {object} STATE - Main loop state object.
 * @return {object} - Object containing parsed information.
 */
module.exports = STATE => {
	// require("../helpers/trace.js")(__filename); // Trace parser.

	// Get global loop state variables.
	let { line, column, i, l, string } = STATE;

	// Parsing vars.
	let state = "sigil"; // Initial parsing state.
	let warnings = []; // Collect all parsing warnings.
	let NODE = {
		node: "NEWLINE",
		sigil: { start: STATE.i, end: STATE.i },
		line,
		startpoint: STATE.i,
		endpoint: STATE.i // Then index at which parsing was ended.
	};

	// Add node to tree.
	require("../helpers/tree-add.js")(STATE, NODE);

	return NODE;
};
