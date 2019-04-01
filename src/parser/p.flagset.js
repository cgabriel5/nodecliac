"use strict";

// Require needed modules.
const issuefunc = require("./p.error.js");
const pflagvalue = require("./p.flag-value.js");
// Get RegExp patterns.
let { r_schars, r_nl, r_nlpipe } = require("./h.patterns.js");

/**
 * Parses flag set line to extract flag name, value, and its other components.
 *
 * ---------- Parsing States Breakdown -----------------------------------------
 * --flag
 * --flag ?
 * --flag =*           "string"
 * --flag =*           'string'
 * --flag =     $(flag-command)
 * --flag = (flag-options-list)
 *       | |                   ^-EOL-Whitespace-Boundary 3
 *       ^-^-Whitespace-Boundary 1/2
 * ^-Symbol
 *  ^-Name
 *        ^-Assignment
 *          ^-Value
 * -----------------------------------------------------------------------------
 *
 * @param  {string} string - The line to parse.
 * @return {object} - Object containing parsed information.
 */
module.exports = (...args) => {
	// Get arguments.
	let [string, i, l, line_num, line_fchar /*indentation*/, , usepipe] = args;

	// Parsing vars.
	let symbol = "";
	let name = "";
	let assignment = "";
	let value = "";
	let qchar; // String quote char.
	let isvspecial;
	let state = "symbol"; // Parsing state.
	let nl_index;
	// Collect all parsing warnings.
	let warnings = [];
	let isopeningpr = false;
	// Capture state's start/end indices.
	let indices = {
		symbol: {
			index: i
		},
		name: {
			start: null,
			end: null,
			boolean: null
		},
		assignment: {
			start: null,
			end: null
		},
		value: {
			start: null,
			end: null
		},
		braces: {
			open: null
		}
	};

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
				name,
				isvspecial
			}
		];
		// Run and return issue.
		return issuefunc.apply(null, paramset1.concat(paramset2));
	};

	// Determine character/delimiter to end on.
	let r_echar = !usepipe ? r_nl : r_nlpipe;

	// Loop over string.
	for (; i < l; i++) {
		// Cache current loop item.
		let char = string.charAt(i);
		let pchar = string.charAt(i - 1);
		let nchar = string.charAt(i + 1);

		// End loop on a new line char.
		if (r_echar.test(char)) {
			// Store newline index.
			nl_index = i;
			break;
		}

		if (state === "symbol") {
			if (char === "-") {
				if (symbol.length <= 2) {
					symbol += char;
				}
			}
			// Hitting anything other than a hyphen ends symbol state.
			else {
				state = "name";
				// Reset index.
				i--;

				// Before ending state check symbol.
				if (!/-{1,2}/.test(symbol)) {
					// Reset index.
					i = line_fchar;
					return issue("error", 2, char);
				}
			}
			// Default parse state to 'name' (l → r : @name=value).
		} else if (state === "name") {
			// If char is the first char...
			if (!name.length) {
				// First char of name must be a letter.
				if (!/[a-zA-Z]/.test(char)) {
					return issue("error", 1, char);
				}
				// Store index.
				indices.name.start = i;
				name += char;
			}
			// Keep building name string...
			else {
				// If char is allowed keep building string.
				if (/[-_.a-zA-Z0-9]/.test(char)) {
					// Give warning for consecutive dots.
					if (char === "." && nchar === ".") {
						issue("warning", 10, nchar);
					}

					// Store index.
					indices.name.end = i;
					name += char;
				}
				// If char is an eq sign change state/reset index.
				else if (char === "=") {
					state = "assignment";
					i--;
				}
				// If char is '?' then it is the flag boolean indicator.
				else if (char === "?") {
					// Store index.
					indices.name.boolean = i;
					name += char;

					// A boolean flag is not allowed any value assignment.
					state = "eol-wsb";
					continue;
				}
				// If we encounter a whitespace character, everything after
				// this point must be a space until we encounter an eq sign
				// or the end-of-line.
				else if (/[ \t]/.test(char)) {
					state = "name-wsb";
					continue;
				}
				// Anything else the character is not allowed.
				else {
					return issue("error", 2, char);
				}
			}
		} else if (state === "name-wsb") {
			// If the character is not a space and the assignment has not
			// been set we are looking for an eq sign.
			if (!/[ \t]/.test(char) && assignment === "") {
				if (char !== "=") {
					return issue("error", 2, char);
				} else {
					state = "assignment";
					i--;
				}
			}
		} else if (state === "assignment") {
			// Store index.
			indices.assignment.start = i;
			indices.assignment.end = i;

			// Set assignment.
			assignment = "=";

			// Check if next character is a muti-flag indicator.
			if (nchar && nchar === "*") {
				assignment += nchar;
				// Reset index to ignore next char.
				i++;
				// Reset assignment end index.
				indices.assignment.end = i;
			}

			state = "value-wsb";
		} else if (state === "value-wsb") {
			// Ignore all beginning consecutive spaces. Once a non-space
			// character is detected switch to value state.
			if (!/[ \t]/.test(char)) {
				state = "value";
				// Set index back 1 to start parsing at the character
				// (this character) that triggered the state switch.
				i--;
				continue;
			}
		} else if (state === "value") {
			// If this is the first char is must be either one of the
			// following: ", ', or a-zA-Z0-9
			if (value === "") {
				if (/["']/.test(char)) {
					qchar = char;
				}
				// Command-flag or options list.
				else if (/[$(]/.test(char)) {
					isvspecial = char === "$" ? "command" : "list";

					if (char === "$" && nchar !== "(") {
						return issue("error", 2, char);
					}

					// Store parentheses index.
					indices.braces.open = i;
				}
				// For anything else give an error.
				else if (!/[a-zA-Z0-9]/.test(char)) {
					return issue("error", 3, char);
				}

				// Store index.
				indices.value.start = i;
				value += char;
			} else {
				// If value is a quoted string we allow for anything.
				// End string at same style-unescaped quote.
				if (qchar || isvspecial) {
					if (char === qchar && pchar !== "\\") {
						state = "eol-wsb";
					}

					// Store index.
					indices.value.end = i;
					value += char;
				} else {
					// We must stop at the first space char.
					if (/[ \t]/.test(char)) {
						state = "eol-wsb";
						i--;
					} else {
						// When building unquoted "strings" warn user
						// when using unescaped special characters.
						if (r_schars.test(char)) {
							// Add warning.
							issue("warning", 5, char);
						}

						// Store index.
						indices.value.end = i;
						value += char;
					}
				}
			}
		} else if (state === "eol-wsb") {
			// Allow trailing whitespace only.
			if (!/[ \t]/.test(char)) {
				return issue("error", 2, char);
			}
		}
	}

	// Check that command-flag/options list is properly closed.
	if (isvspecial) {
		if (value.length > 1) {
			if (value.charAt(value.length - 1) !== ")") {
				return issue("error", 9);
			}
		} else {
			// If check above values and is 'list' then it's not a true list.
			if (value === "(") {
				isvspecial = void 0;
			}
		}
	}

	// If value exists and is quoted, check that is properly quoted.
	if (qchar) {
		// If building quoted string check if it's closed off.
		if (value.charAt(value.length - 1) !== qchar) {
			// Provide first quote index.
			i = indices.value.start;

			return issue("error", 4);
		}
	}

	// If no value was provided give warning.
	if (!assignment && !indices.name.boolean) {
		// Provide original index.
		i = indices.name.end;

		// Add warning.
		issue("warning", 8, "=");
	}

	// If a flag was assigned a flag...
	if (value) {
		// Since value is '(' we set flag and reset value.
		if (value === "(") {
			isopeningpr = true;
			value = [value];
		}
		// Further parse value if not an opening parentheses.
		else {
			// Run flag value parser from here...
			let pvalue = pflagvalue(
				value,
				0, // Index.
				value.length,
				line_num,
				line_fchar,
				indices.value.start, // Value start index.
				isvspecial
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
		}
	}
	// If flag is empty (no assigned value)...
	else if (!value) {
		value = [""];
		isopeningpr = false;
	}

	// Return relevant parsing information.
	return {
		symbol,
		name,
		value,
		special: isvspecial,
		assignment,
		nl_index,
		warnings,
		isopeningpr,
		// Return brace opening index for later error checks.
		// Note: When an opening brace is not provided like in the following
		// example: '--flag' or '--flag=*' we simply use the line_fchar
		// variable so that the pr_open_index value gets set to 1 instead
		// of a negative (as the values cancel each other out). Overall, it
		// really doesn't matter as the pr_open_index does not get used later.
		// This change is more of cosmetic thing. I'd rather see a positive
		// number, in this case the resulting 1 over a negative index value.
		pr_open_index: (indices.braces.open || line_fchar) - line_fchar + 1 // Add 1 to account for 0 index.
	};
};
