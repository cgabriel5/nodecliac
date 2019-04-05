"use strict";

// Require needed modules.
const issuefunc = require("./p.error.js");
const pcommandflag = require("./p.flag-command.js");
// Get RegExp patterns.
let { r_schars } = require("./h.patterns.js");

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
module.exports = (...params) => {
	// Get arguments.
	let [string, i, l, line_num, line_fchar, h, vsi, type] = params;

	// Parsing vars.
	// Note: Parsing the value starts a new loop from 0 to only focus on
	// parsing the provided value. This means the original loop index
	// needs to be accounted for. This variable will track the original
	// index.
	let ci = vsi;
	let value = "";
	let qchar; // String quote char.
	let isvspecial;
	let state = ""; // Parsing state.
	let nl_index;
	let delimiter_count = 0;
	// Collect all parsing warnings.
	let warnings = [];
	let args = [];
	// Capture state's start/end indices.
	let indices = {
		quoted: {
			open: null
		},
		delimiter: {
			last: null
		}
	};

	// // Determine delimiter. Lists can only be delimited by spaces.
	// let delimiter = type === "list" ? /[,]/ : /[ \t,]/;

	// Depending on type, modify index/length.
	if (type) {
		// Modify index/string length when parsing a command-flag/lists to
		// ignore '$(/(', ')' syntax.
		if (type.charAt(0) !== ":") {
			if (type === "command") {
				// i += 2;
			} else {
				// Increment index by one to avoid list starting at '('.
				i++;
				// Decrease length by 1 to skip closing ')'.
				l--;
			}
		}
		// Reset parsing state when type provided from flag options script.
		else {
			if (type !== ":command") {
				state = type.slice(1);

				// Reset everything for quoted strings.
				if (type === ":quoted") {
					type = "";
					state = "";
				}
			} else {
				type = "command";
			}
		}
	}

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

	// Loop over string - command-flag, quoted, regular (escaped value).
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
			// Ignore everything but the following starting characters:
			// command-flag: $(
			// quoted: "  or '
			// normal: anything but unescaped whitespace.
			if (char === "$") {
				if (nchar === "(") {
					state = "command";
					// Reset index to account for '('.
					i++;
					continue;
				} else {
					// If the next char is not '(' return error.
					return issue("error", 2, char);
				}
			} else if (/["']/.test(char)) {
				// Store index.
				indices.quoted.open = ci;
				state = "quoted";
				qchar = char;
			} else {
				state = !/[ \t,]/.test(char) ? "escaped" : "delimiter";
				i--;
			}
		} else {
			if (state === "delimiter") {
				// Run delimiter checks on commas.
				if (char === ",") {
					if (delimiter_count) {
						// Error on consecutive/empty comma delimiter.
						return issue("error", 2, char);
					}

					// Store delimiter index.
					indices.delimiter.last = ci;

					// Increment delimiter counter.
					delimiter_count++;
				}

				// Note: If args exists and there is no state then the state
				// was reset. In this case if the char is not a delimiter we
				// give an error. For example, this covers the following:
				// '"a""b"' when it should really be: '"a" "b"' (delimited).
				if (!/[ \t,]/.test(char)) {
					return issue("error", 2, char);
				}

				state = "";
			} else if (state === "escaped") {
				// Build value until an unescaped whitespace char is hit.
				if (/[ \t]/.test(char) && pchar !== "\\") {
					// Get value information.
					let vlength = value.length;
					let lchar = value.charAt(vlength - 1); // Value's last char.
					let lschar = value.charAt(vlength - 2); // Second to last char.

					// If the value's last character is a quote and the
					// first character of the string is not the same style
					// quote then give an error.
					if (
						/["']/.test(lchar) &&
						lschar !== "\\" &&
						value.charAt(0) !== lchar
					) {
						// Reset index to exclude current char (space char).
						ci--;

						// Improperly quoted string, give error.
						return issue("error", 4);
					}

					// Reset delimiter count/index.
					delimiter_count = 0;
					indices.delimiter.last = null;

					// Reset state
					state = "delimiter";
					// Store value.
					args.push(value);
					// Clear value.
					value = "";
					// Reset index to set delimiter state.
					i--;
					continue;
				}
				// When building unquoted "strings" warn user
				// when using unescaped special characters.
				if (r_schars.test(char) && pchar !== "\\") {
					// Add warning.
					issue("warning", 5, char);
				}

				// Append character to current value string.
				value += char;
			} else if (state === "quoted") {
				if (char === qchar && pchar !== "\\") {
					// Reset delimiter count/index.
					delimiter_count = 0;
					indices.delimiter.last = null;

					// Reset state
					state = "delimiter";
					// Store value.
					args.push(`${qchar}${value}${qchar}`);
					// Clear value.
					value = "";
					// Clear stored index.
					indices.quoted.open = null;
					continue;
				}

				// Check that string was properly closed.
				if (i === l - 1) {
					if (value.charAt(value.length - 1) !== qchar) {
						// Reset index.
						ci = indices.quoted.open;

						// String was never closed so give error.
						return issue("error", 4, char);
					}
				}

				// Append character to current value string.
				value += char;
			} else if (state === "command") {
				// Run command flag parser from here...
				let pvalue = pcommandflag(
					string,
					i,
					string.length,
					line_num,
					line_fchar,
					h,
					vsi,
					type
				);

				// Join warnings.
				if (pvalue.warnings.length) {
					warnings = warnings.concat(pvalue.warnings);
				}
				// If error exists return error.
				if (pvalue.code) {
					return pvalue;
				}

				// Reset delimiter count/index.
				delimiter_count = 0;
				indices.delimiter.last = null;

				// Reset state
				state = "delimiter";
				// Store value.
				args.push(`$(${pvalue.cmd_str})`);
				// Clear value.
				value = "";

				// Reset index.
				i = pvalue.index;
				continue;
			}
		}
	}

	// If the delimiter index remained then there is a trailing delimiter.
	if (indices.delimiter.last) {
		// Reset index.
		ci = indices.delimiter.last;

		// Issue error.
		return issue("error", 2, ",");
	}

	// Add final value if it exists.
	if (value) {
		// If the final state was left as escaped check value for improperly
		// quoted (missing left quote) string/value.
		if (state === "escaped") {
			// Get value information.
			let vlength = value.length;
			let lchar = value.charAt(vlength - 1); // Value's last char.
			let lschar = value.charAt(vlength - 2); // Second to last char.

			// If the value's last character is a quote and the
			// first character of the string is not the same style
			// quote then give an error.
			if (
				/["']/.test(lchar) &&
				lschar !== "\\" &&
				value.charAt(0) !== lchar
			) {
				// Improperly quoted string, give error.
				return issue("error", 4);
			}
		}

		args.push(value);
		// Reset value.
		value = "";
	}

	// If arguments array is empty then nothing was parsed. Meaning no
	// arguments were provided.
	if (!args.length) {
		// Reset index.
		ci = vsi;

		// Add warning.
		issue("warning", 10);
	}

	// Highlight option list values.
	args = h(args, "cmd-flag", ":/1");

	// Return relevant parsing information.
	return {
		index: i,
		string,
		value,
		special: isvspecial,
		nl_index,
		warnings,
		args
	};
};
