"use strict";

// Require needed modules.
const issuefunc = require("../helpers/issue.js");
const pflagvalue = require("../parsers/flag-value.js");
// Get RegExp patterns.
let { r_schars, r_nl, r_nlpipe } = require("../helpers/patterns.js");

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
module.exports = (params = {}) => {
	// Trace parser.
	require("../helpers/trace.js")(__filename);

	// Get params.
	let { str = [], usepipe = false } = params;

	// Get globals.
	let string = str[1] || global.$app.get("string");
	let i = +(str[0] || global.$app.get("i"));
	let l = str[2] || global.$app.get("l");
	// let line_num = global.$app.get("line_num");
	let line_fchar = global.$app.get("line_fchar");
	let h = global.$app.get("highlighter");
	let lookup = global.$app.get("lookup");
	let currentchain = global.$app.get("currentchain");
	let flags = lookup[currentchain]; // Get command's flag list.
	let keywords = global.$app.get("keywords");

	// Parsing vars.
	let keyword = "";
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
	let valid_keywords = ["default", "always"];
	// Capture state's start/end indices.
	let indices = {
		keyword: {
			start: null,
			end: null
		},
		symbol: {
			start: i,
			end: null
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
		// Run and return issue.
		return issuefunc(i, __filename, warnings, state, type, code, {
			// Parser specific variables.
			char,
			name,
			isvspecial,
			currentchain
		});
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
		if (r_echar.test(char) && pchar !== "\\") {
			// If char is a pipe delimiter and it's the last character
			// of the line give a warning.
			if (char === "|" && (!nchar || /[^-a-z]/.test(nchar))) {
				return issue("error", 2, !nchar ? char : nchar);
			}

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
					state = "value-wsb";
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
			if (char === "-") {
				// Store index.
				indices.symbol.end = i;
				symbol += char;
			}
			// Hitting anything other than a hyphen ends symbol state.
			else {
				// If symbol is empty but the state changed then the
				// character is not allowed.
				if (!symbol) {
					// Issue error.
					return issue("error", 2, string.charAt(i));
				}

				state = "name";
				// Reset index.
				i--;

				// Before ending symbol state check length.
				let max_hyphens = 2;
				let sym_len = symbol.length;
				if (sym_len > max_hyphens) {
					// Reset index.
					i = indices.symbol.end - sym_len + max_hyphens;
					i++; // Add 1 to set at offending character.

					// Issue error.
					return issue("error", 2, string.charAt(i));
				}
			}
		}
		// Default parse state to 'name'.
		else if (state === "name") {
			// If char is the first char...
			if (!name.length) {
				// First char of name must be a letter.
				if (!/[a-zA-Z]/.test(char)) {
					return issue("error", 1, char);
				}
				// Store index.
				indices.name.start = i;
				// Store ending index as well for single letter flags.
				indices.name.end = i;
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
			// following: ", ', or -:a-zA-Z0-9
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
				else if (!/[-:a-zA-Z0-9]/.test(char)) {
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

	// If no value (only hyphen(s)) was provided give warning.
	if (!assignment && !indices.name.boolean && !keyword) {
		// Reset index to symbol end.
		i = indices.symbol.end;

		// Add warning.
		issue("warning", 8, "=");
	}

	// Store as global to access in other parsers (for dupe checks).
	global.$app.vars.currentflag = `${symbol}${name}`;
	global.$app.size(1); // Increment size by 1.

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
			let pvalue = pflagvalue({
				str: ["0", value, value.length], // Provide new string information.
				vsi: indices.value.start, // Value start index.
				type: isvspecial
			});

			// Join warnings.
			if (pvalue.warnings.length) {
				warnings = warnings.concat(pvalue.warnings);
			}
			// If error exists return error.
			if (pvalue.code) {
				return pvalue;
			}

			// Reset value.
			value = pvalue.args;

			// Store highlighted args.
			value.hargs = [...pvalue.h.args]; // Highlight option list values.

			// Reset index. Combine indices.
			i += pvalue.index;
		}
	}
	// If flag is empty (no assigned value)...
	else if (!value) {
		value = [""];
		isopeningpr = false;
	}

	// If no highlighted args set a default.
	if (!value.hargs) {
		value.hargs = [];
	}

	// Check if flag is a duplicate.
	if (flags && flags.has(`${symbol}${name}${assignment}`)) {
		// Reset index.
		i = indices.name.end;

		// Add warning.
		issue("warning", 11, name);
	}

	// Check if command chain is a duplicate.
	if (keyword) {
		// Validate keyword here to catch following invalid cases:
		// 'default = default $("command")|d|a' ←
		if (!valid_keywords.includes(keyword)) {
			return issue(
				"error",
				2,
				// Provide last character in keyword to error.
				string.charAt(indices.keyword.end)
			);
		}

		if (currentchain) {
			// If setting exists give an dupe/override warning.
			if (Object.prototype.hasOwnProperty.call(keywords, currentchain)) {
				// Reset index to point to keyword.
				i = indices.keyword.start;

				// Add warning.
				issue("warning", 12, currentchain);
			}

			// Give warning for empty default command value.
			if (!value[0]) {
				// Reset index to point to keyword.
				i = indices.keyword.end;

				// Add warning.
				issue("warning", 13, null);
			}
		}

		// Add highlighted/non-highlighted keywords.
		keyword = [keyword, h(keyword, "keyword")];
	} else {
		// Set keyword to nothing.
		keyword = null;
	}

	// Return relevant parsing information.
	return {
		keyword,
		symbol,
		name,
		// Note: Since the name 'value' is a bit misleading as it's actually
		// an array of values rename to 'args' before passing object.
		args: value,
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
		pr_open_index: (indices.braces.open || line_fchar) - line_fchar + 1, // Add 1 to account for 0 index.
		h: {
			// Add syntax highlighting.
			name: h(name, "flag"),
			hargs: h(value.hargs, "value", ":/3") // Highlight option list values.
		}
	};
};
