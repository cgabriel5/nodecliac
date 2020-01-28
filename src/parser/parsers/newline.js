"use strict";

const node = require("../helpers/nodes.js");
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
	let NODE = node(S, "NEWLINE");

	NODE.sigil.start = S.i;
	NODE.sigil.end = S.i;

	S.line++;
	S.column = 0;
	S.sol_char = "";

	add(S, NODE); // Add node to tree.
};
