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
 * @param  {object} S - Main loop state object.
 * @return {undefined} - Nothing is returned.
 */
module.exports = S => {
	let { line } = S;

	// Parsing vars.
	let NODE = {
		node: "NEWLINE",
		sigil: { start: S.i, end: S.i },
		line,
		startpoint: S.i,
		endpoint: S.i // Index where parsing ended.
	};

	S.line++;
	S.column = 0;
	S.sol_char = "";

	add(S, NODE); // Add node to tree.
};
