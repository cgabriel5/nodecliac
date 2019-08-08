"use strict";

/**
 * Add parsed node to parsed tree.
 *
 * @param  {object} object - Main loop state object.
 * @return {object} - Object containing parsed information (node).
 */
module.exports = (STATE, DATA) => {
	// Get line.
	let line = STATE.line;
	let tree = STATE.DB.tree;

	// If line exists in tree add to it else create it first.
	if (tree[line]) {
		tree[line].push(DATA);
	} else {
		tree[line] = [DATA];
	}
};
