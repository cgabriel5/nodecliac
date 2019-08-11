"use strict";

/**
 * Add parsed node to parsed tree.
 *
 * @param  {object} object - Main loop state object.
 * @return {object} - Object containing parsed information (node).
 */
module.exports = (STATE, NODE) => {
	// Get line.
	let line = STATE.line;
	let tree = STATE.DB.tree;

	// If line exists in tree add to it else create it first.
	if (tree[line]) {
		tree[line].push(NODE);
	} else {
		tree[line] = [NODE];
	}
};
