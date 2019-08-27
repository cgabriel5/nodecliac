"use strict";

/**
 * Add parsed node to syntax tree.
 *
 * @param  {object} STATE - Main loop state object.
 * @param  {object} NODE - Object containing parsed information (node).
 * @return {undefined} - Nothing is returned.
 */
module.exports = (STATE, NODE) => {
	// Get line.
	// let line = STATE.line;
	let tree = STATE.tables.tree;

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
