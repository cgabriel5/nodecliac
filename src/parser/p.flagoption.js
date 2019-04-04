"use strict";

// Require needed modules.
const issuefunc = require("./p.error.js");
const pflagvalue = require("./p.flag-value.js");
// Get RegExp patterns.
let { r_nl } = require("./h.patterns.js");

/**
 * Parses flag option line.
 *
 * ---------- Parsing States Breakdown -----------------------------------------
 * - value
 *  |     ^-EOL-Whitespace-Boundary 2
 *  ^-Whitespace-Boundary 1
 * ^-Symbol
 *  ^-Value
 * -----------------------------------------------------------------------------
 *
 * @param  {string} string - The line to parse.
 * @return {object} - Object containing parsed information.
 */
module.exports = (...args) => {
	// Get arguments.
	let [string, i, l, line_num, line_fchar, h] = args;

	// Parsing vars.
	let symbol = "";
	let boundary = "";
	let assignment = "";
	let value = "";
	// let qchar; // String quote char.
	let state = "symbol"; // Parsing state.
	let nl_index;
	// Collect all parsing warnings.
	let warnings = [];
	// Capture state's start/end indices.
	let indices = {
		symbol: {
			index: i
		},
		boundary: {
			start: null,
			end: null
		},
		assignment: {
			index: null
		},
		value: {
			start: null,
			end: null
		}
	};

	// Wrap issue function to add fixed parameters.
	let issue = (type = "error", code, char = "") => {
		// Use multiple parameter arrays to flatten function.
		let paramset1 = [string, i, l, line_num, line_fchar];
		let paramset2 = [__filename, warnings, state, type, code, char];
		// Run and return issue.
		return issuefunc.apply(null, paramset1.concat(paramset2));
	};

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
		if (state === "symbol") {
			// Check that first char is indeed a hyphen symbol '-'.
			if (char !== "-") {
				return issue("error", 3, char);
			}

			// Store index.
			indices.symbol.index = i;
			state = "boundary";
			symbol = char;
		} else if (state === "boundary") {
			// Boundary must contain at least a single whitespace char.
			if (boundary === "") {
				// First boundary char must be space.
				if (/[ \t]/.test(char)) {
					// Store indices.
					indices.boundary.start = i;
					indices.boundary.end = i;

					boundary += char;
				} else {
					// If first char is not a whitespace give an error.
					return issue("error", 3, char);
				}
			} else {
				// Only whitespace.
				if (/[ \t]/.test(char)) {
					// Store index.
					indices.boundary.end = i;
					boundary += char;
				} else {
					// Store index.
					indices.value.start = i;
					state = "value";
					i--;
				}
			}
		} else if (state === "value") {
			value += char;
		}
	}

	let type;
	// Determine value type.
	if (value.charAt(0) === "$") {
		type = "command";
	} else if (/^["']/.test(value)) {
		type = ":quoted";
	} else {
		type = ":escaped";
	}

	// If option does not exist then value will be empty (dangling '-').
	if (!value) {
		// Reset index so it points to '-' symbol.
		i = indices.symbol.index;

		issue("warning", 0, "-");
	} else {
		// Run flag value parser from here...
		let pvalue = pflagvalue(
			value,
			0, // Index.
			value.length,
			line_num,
			line_fchar,
			h,
			indices.value.start, // Value start index.
			type
		);

		// Reset value.
		value = pvalue.args;
		// Reset index. Combine indices.
		i += pvalue.index;

		// Join warnings.
		if (pvalue.warnings.length) {
			warnings = warnings.concat(pvalue.warnings);
		}
		// If error exists return error.
		if (pvalue.code) {
			return pvalue;
		}

		// If value exists and is quoted, check that is properly quoted.
		if (type === ":quoted") {
			// If building quoted string check if it's closed off.
			if (value[0].charAt(value[0].length - 1) !== value[0].charAt(0)) {
				// Set index to first quote.
				i = indices.value.start;

				return issue("error", 4);
			}
		}
	}

	// Highlight option list values.
	value = h(value, "value", ":/2");

	// Return relevant parsing information.
	return { symbol, value, assignment, nl_index, warnings };
};
