"use strict";

// Require needed modules.
const issuefunc = require("../helpers/issue.js");
const pflagvalue = require("../parsers/flag-value.js");
// Get RegExp patterns.
let { r_nl } = require("../helpers/patterns.js");

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
module.exports = () => {
	// Trace parser.
	require("../helpers/trace.js")(__filename);

	// Get globals.
	let string = global.$app.get("string");
	let i = global.$app.get("i");
	let l = global.$app.get("l");
	// let line_num = global.$app.get("line_num");
	// let line_fchar = global.$app.get("line_fchar");
	let h = global.$app.get("highlighter");
	let keywords = global.$app.get("keywords");
	let currentchain = global.$app.get("currentchain");

	// Parsing vars.
	let keyword = "";
	let symbol = "";
	let boundary = "";
	let assignment = "";
	let value = "";
	// let qchar; // String quote char.
	let state = "symbol"; // Parsing state.
	let nl_index;
	// Collect all parsing warnings.
	let warnings = [];
	let valid_keywords = ["default", "always"];
	// Capture state's start/end indices.
	let indices = {
		keyword: {
			start: null,
			end: null
		},
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
		// Run and return issue.
		return issuefunc(i, __filename, warnings, state, type, code, {
			// Parser specific variables.
			char,
			currentchain
		});
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

		// If a symbol does not exist then check to see if the char is a 'd'.
		// If so, then set state to keyword to check for 'default' keyword.
		if (!symbol && !keyword && /[a-z]/.test(char)) {
			// Store index.
			indices.keyword.start = i;
			state = "keyword";
		}

		// Parse keyword option line.
		if (state === "keyword") {
			// Keyword must only contain letters. Parsing for keyword must
			// end at the end of line or when a non-letter character is
			// found. Once all letter characters are rounded up the final
			// collection must match one of the allowed keywords.
			if (/[a-z]/.test(char)) {
				// Store index.
				indices.keyword.end = i;
				state = "keyword";
				keyword += char;
			} else {
				// Check if keyword is valid.
				if (!valid_keywords.includes(keyword)) {
					return issue(
						"error",
						2,
						// Provide last character in keyword to error.
						string.charAt(indices.keyword.end)
					);
				}

				if (/[ \t]/.test(char)) {
					state = "boundary";
					i--;
				}
				// Give error for any other character.
				else {
					return issue("error", 2, char);
				}
			}
		}
		// Symbol parse state.
		else if (state === "symbol") {
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
		let pvalue = pflagvalue({
			str: ["0", value, value.length], // Provide new string information.
			vsi: indices.value.start, // Value start index.
			type
		});

		// Reset value.
		value = pvalue.args;

		// Store highlighted args.
		value.hargs = h([...pvalue.h.args], "value", ":/2"); // Highlight option list values.
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

	// Check if command chain is a duplicate.
	if (keyword) {
		if (currentchain) {
			// If setting exists give an dupe/override warning.
			if (keywords.hasOwnProperty(currentchain)) {
				// Reset index to point to keyword.
				i = indices.keyword.start;

				// Add warning.
				issue("warning", 5, keyword);
			}

			// Give warning for empty default command value.
			if (!value) {
				// Reset index to point to keyword.
				i = indices.keyword.end;

				// Add warning.
				issue("warning", 6, null);
			}
		}

		// Add highlighted/non-highlighted keywords.
		keyword = [keyword, h(keyword, "keyword")];
	} else {
		// Set keyword to nothing.
		keyword = null;
	}

	// Return relevant parsing information.
	return { keyword, symbol, value, assignment, nl_index, warnings };
};
