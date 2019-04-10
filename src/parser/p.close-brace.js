"use strict";

// Get needed modules.
const issuefunc = require("./p.error.js");
// Get RegExp patterns.
let { r_nl } = require("./h.patterns.js");

/**
 * Parses closing brace (either ']' or ')') line.
 *
 * ---------- Parsing States Breakdown -----------------------------------------
 * ] or )
 * ^-Closing-Bracket
 *  ^-EOL-Whitespace-Boundary
 * -----------------------------------------------------------------------------
 *
 * @param  {string} string - The line to parse.
 * @return {object} - Object containing parsed information.
 */
module.exports = () => {
	// Get globals.
	let string = global.$app.get("string");
	let i = global.$app.get("i");
	let l = global.$app.get("l");

	// Parsing vars.
	let state = "eol-wsb"; // Parsing state.
	let nl_index;
	// Collect all parsing warnings.
	let warnings = [];

	// Wrap issue function to add fixed parameters.
	let issue = (type = "error", code, char = "") => {
		// Run and return issue.
		return issuefunc(i, __filename, warnings, state, type, code, char);
	};

	// Increment index by 1 to skip brace character.
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

		// Default parse state to 'eol-wsb'.
		if (state === "eol-wsb") {
			// Characters after ']' must be trailing whitespace.
			if (!/[ \t]/.test(char)) {
				return issue("error", 1, char);
			}
		}
	}

	// Return relevant parsing information.
	return { nl_index, warnings };
};
