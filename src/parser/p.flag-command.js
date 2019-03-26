// Get needed modules.
const issuefunc = require("./p.error.js");

/**
 * Parses command flag into its individual arguments.
 *
 * ---------- Parsing States Breakdown -----------------------------------------
 * $"text characters",
 *                  ^-Delimiter
 *                   ^-EOL-Whitespace-Boundary
 * ^-Command-String-Indicator?
 *  ^-Symbol
 *   ^-Text-Character
 * -----------------------------------------------------------------------------
 *
 * @param  {string} string - The line to parse.
 * @return {object} - Object containing parsed information.
 */
module.exports = (...args) => {
	// Get arguments.
	let [string, i, l, line_num, line_fchar, vsi, type] = args;

	// If parsing a list reduce length to ignore closing ')'. Otherwise,
	// leave length be as a command, for example, does get wrapped with '()'.
	if (type === "list") {
		l--;
	}

	// Parsing vars.
	// Note: Parsing the value starts a new loop from 0 to only focus on
	// parsing the provided value. This means the original loop index
	// needs to be accounted for. This variable will track the original
	// index.
	let ci = vsi;
	let value = "";
	let qchar; // String quote char.
	let state = ""; // Parsing state.
	let closed = false;
	let delimiter_count = 0;
	let cmd_str = "";
	// Collect all parsing warnings.
	let warnings = [];
	// Capture state's start/end indices.
	let indices = {
		delimiter: {
			last: null
		}
	};

	// Get RegExp patterns.
	let { r_schars, r_nl } = require("./regexpp.js");

	// Wrap issue function to add fixed parameters.
	let issue = (type = "error", code, char = "") => {
		// Use multiple parameter arrays to flatten function.
		let paramset1 = [string, i, l, line_num, line_fchar];
		let paramset2 = [
			__filename,
			warnings,
			state,
			type,
			code,
			char,
			// Parser specific variables.
			{
				ci
			}
		];
		// Run and return issue.
		return issuefunc.apply(null, paramset1.concat(paramset2));
	};

	// Keep a list of unique loop iterations for current index.
	let last_index;
	// Account for command-flag/list '$(' or '(' syntax removal.
	ci += i;

	// Loop over string.
	for (; i < l; i++) {
		// Cache current loop item.
		let char = string.charAt(i);
		let pchar = string.charAt(i - 1);
		let nchar = string.charAt(i + 1);

		// Note: Since loop logic can back track (e.g. 'i--;'), we only
		// increment current index (original index) on unique iterations.
		if (last_index !== i) {
			// Update last index to the latest unique iteration index.
			last_index = i;
			// Increment current index.
			ci += 1;
		}

		// Determine the initial parsing state.
		if (!state) {
			// Ignore all but: quotes (" or ') and comma delimiter (',').
			if (/["']/.test(char)) {
				delimiter_count = 0;
				indices.delimiter.last = null;

				state = "quoted";
				qchar = char;
			} else if (char === ",") {
				state = "delimiter";

				// Return error if consecutive/empty arguments.
				if (delimiter_count) {
					return issue("error", 5, char);
				}
				// Increment delimiter counter.
				delimiter_count++;

				// Store delimiter index.
				indices.delimiter.last = ci;

				i--;
			} else if (char === ")") {
				state = "closing-parens";
				i--;
			} else {
				// If char is anything other than q quote or a comma
				// the character is not allowed so return an error.
				if (!/[ \t]/.test(char)) {
					return issue("error", 2, char);
				}
			}
		} else {
			if (state === "delimiter") {
				state = "";
			} else if (state === "quoted") {
				if (char === qchar && pchar !== "\\") {
					// Reset state
					state = "";
					// Store value.
					value = `${qchar}${value}${qchar}`;

					if (!cmd_str) {
						cmd_str = value;
					} else {
						cmd_str += ",";
						cmd_str += value;
					}

					// Clear value.
					value = "";
					continue;
				}

				// Check that string was properly closed.
				if (i === l - 2) {
					if (value.charAt(value.length - 1) !== qchar) {
						// String was never closed so give error.
						return issue("error", 4, char);
					}
				}

				// Append character to current value string.
				value += char;
			} else if (state === "closing-parens") {
				// Make a final check. The char after the closing ')'
				// has to be an end-of-line character or a space.
				if (nchar && !/[ \t\)]/.test(nchar)) {
					return issue("error", 2, nchar);
				}

				// Once closing ')' has been detected, stop loop.
				// Reset index so it points to the ')' and not the next char.
				closed = true;
				state = "";
				break;
			}
		}
	}

	// If the command-flag was never closed give an error. This means the
	// ')' character was missing.
	if (!closed) {
		return issue("error", 6);
	}

	// If the delimiter index remained then there is a trailing delimiter.
	if (indices.delimiter.last) {
		// Reset index.
		ci = indices.delimiter.last;

		// Issue error.
		return issue("error", 5);
	}

	// Add final value if it exists.
	if (value) {
		value = `${qchar}${value}${qchar}`;
		cmd_str += ",";
		cmd_str += value;
		// Reset value.
		value = "";
	}

	// Return relevant parsing information.
	return {
		cmd_str,
		warnings
	};
};
