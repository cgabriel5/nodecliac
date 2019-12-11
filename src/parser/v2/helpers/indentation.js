"use strict";

/**
 * Some line types can't begin w/ whitespace. If they do give an error.
 *
 * @param  {object} STATE - Main loop state object.
 * @param  {string} line_type - The line's line type.
 * @return {undefined} - Nothing is returned.
 */
module.exports = (STATE, line_type) => {
	let issue = STATE.utils.functions.loop.issue; // Utility functions and constants.

	let linestarts = STATE.tables.linestarts; // Vars.
	let r_linetypes = /(setting|variable|command)/; // Lines can't be indented.

	// Following commands cannot begin with any whitespace.
	if (linestarts[STATE.line] !== STATE.i && r_linetypes.test(line_type)) {
		STATE.column = 1; // Reset column/index to start of line.
		issue.error(STATE, 11); // Note: Line cannot begin with whitespace.
	}
};
