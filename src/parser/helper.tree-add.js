"use strict";

/**
 * Add parsed node to parsed tree.
 *
 * @param  {object} object - Main loop state object.
 * @return {object} - Object containing parsed information (node).
 */
module.exports = (STATE, NODE) => {
	// Get line.
	// let line = STATE.line;
	let tree = STATE.DB.tree;

	// Add nodes entry if not already added.
	if (!tree.nodes) {
		tree.nodes = [NODE];
	} else {
		tree.nodes.push(NODE);
	}

	// // If line exists in tree add to it else create it first.
	// if (tree[line]) {
	// 	tree[line].push(NODE);
	// } else {
	// 	tree[line] = [NODE];
	// }
};
