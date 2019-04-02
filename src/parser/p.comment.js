"use strict";

// // Get needed modules.
// const issuefunc = require("./p.error.js");
// Get RegExp patterns.
let { r_nl } = require("./h.patterns.js");

/**
 * Parses comment lines.
 *
 * ---------- Parsing States Breakdown -----------------------------------------
 * #
 * ^-Symbol
 *  ^-Comment-Char *(all characters until newline '\n')
 * -----------------------------------------------------------------------------
 *
 * @param  {string} string - The line to parse.
 * @return {object} - Object containing parsed information.
 */
module.exports = (...args) => {
	// Get arguments.
	let [string, i, l /*line_num, line_fchar*/] = args;

	// Parsing vars.
	let state = "comment-char"; // Parsing state.
	let nl_index;
	// Collect all parsing warnings.
	let warnings = [];
	let comment = "";

	// // Wrap issue function to add fixed parameters.
	// let issue = (type = "error", code, char = "") => {
	// 	// Use multiple parameter arrays to flatten function.
	// 	let paramset1 = [string, i, l, line_num, line_fchar];
	// 	let paramset2 = [__filename, warnings, state, type, code, char];
	// 	// Run and return issue.
	// 	return issuefunc.apply(null, paramset1.concat(paramset2));
	// };

	// Increment index by 1 to skip symbol character.
	i++;

	// Loop over string.
	for (; i < l; i++) {
		// Cache current loop item.
		let char = string.charAt(i);
		// let pchar = string.charAt(i - 1);
		// let nchar = string.charAt(i + 1);

		// End loop on a new line char.
		if (r_nl.test(char)) {
			// Store newline index.
			nl_index = i;
			break;
		}

		// Default parse state.
		if (state === "comment-char") {
			// Allow for any characters in comments.
			comment += char;
		}
	}

	// Return relevant parsing information.
	return { comment, nl_index, warnings };
};