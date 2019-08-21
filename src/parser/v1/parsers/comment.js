"use strict";

// // Get needed modules.
// const issuefunc = require("../helpers/issue.js");
// Get RegExp patterns.
let { r_nl } = require("../helpers/patterns.js");

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
module.exports = () => {
	// Trace parser.
	require("../helpers/trace.js")(__filename);

	// Get globals.
	let string = global.$app.get("string");
	let l = global.$app.get("l");
	let i = global.$app.get("i");
	let h = global.$app.get("highlighter");

	// Parsing vars.
	let state = "comment-char"; // Parsing state.
	let nl_index;
	// Collect all parsing warnings.
	let warnings = [];
	let comment = "";

	// // Wrap issue function to add fixed parameters.
	// let issue = (type = "error", code, char = "") => {
	// 	// Run and return issue.
	// 	return issuefunc(i, __filename, warnings, state, type, code, {
	// 		// Parser specific variables.
	// 		char
	// 	});
	// };

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
	return {
		comment,
		nl_index,
		warnings,
		h: { comment: h(comment, "comment") }
	};
};
