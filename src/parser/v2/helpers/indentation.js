"use strict";

// Get needed modules.
let issue = require("./issue.js");
let { r_letter, r_whitespace } = require("./patterns.js");

/**
 * Some line types cannot be preceded with (whitespace )indentation. If they
 *     do give an error.
 *
 * @param  {object} STATE - Main loop state object.
 * @param  {string} line_type - The line's line type.
 * @return {string} - The line's type.
 */
module.exports = (STATE, line_type) => {
	// Vars.
	let linestarts = STATE.tables.linestarts;
	// Note: Following line types cannot have any whitespace indentation.
	let r_line_types = /(setting|variable|command)/;

	// Following commands cannot begin with any whitespace.
	if (linestarts[STATE.line] !== STATE.i && r_line_types.test(line_type)) {
		// Reset column/index to first start of line.
		STATE.column = 1;

		issue.error(STATE, 11); // Note: Line cannot begin with whitespace.
	}
};
