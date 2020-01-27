"use strict";

const add = require("../helpers/tree-add.js");

/**
 * Newline parser.
 *
 * ---------- Parsing Breakdown ------------------------------------------------
 * \n
 * ^-Newline character.
 * -----------------------------------------------------------------------------
 *
 * @param  {object} STATE - Main loop state object.
 * @return {undefined} - Nothing is returned.
 */
module.exports = STATE => {
	let { line, utils } = STATE; // Loop state vars.

	// Parsing vars.
	let NODE = {
		node: "NEWLINE",
		sigil: { start: STATE.i, end: STATE.i },
		line,
		startpoint: STATE.i,
		endpoint: STATE.i // Index where parsing ended.
	};

	add(STATE, NODE); // Add node to tree.
};
