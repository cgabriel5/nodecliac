"use strict";

const node = require("../helpers/nodes.js");
const add = require("../helpers/tree-add.js");

/**
 * ----------------------------------------------------------- Parsing Breakdown
 * \n
 * ^-Newline character.
 * -----------------------------------------------------------------------------
 *
 * @param  {object} S - State object.
 * @return {undefined} - Nothing is returned.
 */
module.exports = (S) => {
	let N = node(S, "NEWLINE");

	N.start = N.end = S.i;

	S.line++;
	S.column = 0;
	S.sol_char = "";

	add(S, N);
};
