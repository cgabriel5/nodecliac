"use strict";

// Require needed modules.
const issuefunc = require("./p.error.js");
const pcommandflag = require("./p.flag-command.js");
const ptemplatestr = require("./p.template-string.js");
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
module.exports = (params = {}) => {
	// Trace parser.
	require("./h.trace.js")(__filename);

	// Get params.
	let { str = [], vsi, type } = params;

	// Get globals.
	let string = str[1] || global.$app.get("string");
	let i = +(str[0] || global.$app.get("i"));
	let l = str[2] || global.$app.get("l");
	let line_num = global.$app.get("line_num");
	let line_fchar = global.$app.get("line_fchar");
	let h = global.$app.get("highlighter");
	let highlight = global.$app.get("highlight");
	let lookup = global.$app.get("lookup");
	let currentchain = global.$app.get("currentchain");
	let currentflag = global.$app.get("currentflag");
	let flags = lookup[currentchain]; // Get command's flag list.

	// Parsing vars.
	// Note: Parsing the value starts a new loop from 0 to only focus on
	// parsing the provided value. This means the original loop index
	// needs to be accounted for. This variable will track the original
	// index.
	let ci = vsi;
	let value = "";
	let hvalue = ""; // Highlighted version.
	let qchar; // String quote char.
	let isvspecial;
	let state = ""; // Parsing state.
	let nl_index;
	let delimiter_count = 0;
	// Collect all parsing warnings.
	let warnings = [];
	let args = [];
	let hargs = [];
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
		// Run and return issue.
		return issuefunc(i, __filename, warnings, state, type, code, {
			// Parser specific variables.
			ci,
			char,
			flag: currentflag
		});
	};

	/**
	 * Check if value is a duplicate value.
	 *
	 * @param  {string} value - The flag's value.
	 * @param  {number} index - The value's positional index.
	 * @param  {string} hvalue - cmd-flag highlighted string value.
	 * @return {undefined} - Nothing is returned.
	 */
	let isdupeval = function(value, index, hvalue) {
		if (!currentflag) {
			return;
		}

		// Build --flag=value string.
		let flagvalue = `${currentflag}=${value}`;
		// Get oneliner flag set.
		let flagset_oneliner = global.$app.vars.oneliner;

		// Note: Since value is being stored in the warnings array before
		// final command-flag highlighting is applied we need to run
		// highlight on value before storing.
		if (hvalue && highlight) {
			value = h([hvalue], "cmd-flag", ":/1")[0];
		}

		// Check if flag is a duplicate.
		if (
			// Check main flag set.
			(flags && flags.has(flagvalue)) ||
			// Check local value array.
			isdupeval.values.has(value) ||
			// Check global oneliner flag set.
			(flagset_oneliner && flagset_oneliner.has(flagvalue))
		) {
			// Store index to later reset it back.
			let old_index = i;

			// Reset index.
			i = index;

			// Add warning.
			issue("warning", 12, value);

			// Restore index after issuing warning.
			i = old_index;
		}

		// Store the value.
		isdupeval.values.add(value);

		// Store flag=value in oneliner flag set to access in other scripts.
		if (flagset_oneliner) {
			flagset_oneliner.add(flagvalue);
		}
	};
	// Store currently parsed values.
	isdupeval.values = new Set();

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

					// Check for duplicate values.
					isdupeval(value, ci);

					// Reset state
					state = "delimiter";
					// Store value.
					args.push(value);
					hargs.push(hvalue);
					// Clear value.
					value = "";
					hvalue = "";
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
				hvalue += char;
			} else if (state === "quoted") {
				if (char === qchar && pchar !== "\\") {
					// Reset state
					state = "delimiter";
					// Build string value.
					value = `${qchar}${value}${qchar}`;
					hvalue = `${qchar}${hvalue}${qchar}`;

					// If string is empty give a warning.
					if (/^("|')\1$/.test(value)) {
						// Store index to later reset it back.
						let old_ci = ci;

						// Reset index to point to opening quote.
						ci--;

						// Issue warning.
						issue("warning", 11, `${char}${char}`);

						// Restore index after issuing warning.
						ci = old_ci;
					}

					// Reset delimiter count/index.
					delimiter_count = 0;
					indices.delimiter.last = null;

					// Check for duplicate values.
					isdupeval(value, ci);

					// Store value.
					args.push(value);
					hargs.push(hvalue);
					// Clear value.
					value = "";
					hvalue = "";
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

				// Check for template strings (variables).
				if (char === "$" && pchar !== "\\" && nchar === "{") {
					// Run template-string parser from here...
					let pvalue = ptemplatestr({
						// Provide new string information.
						str: [i + 1, string, string.length]
					});

					// Join warnings.
					if (pvalue.warnings.length) {
						warnings = warnings.concat(pvalue.warnings);
					}
					// If error exists return error.
					if (pvalue.code) {
						return pvalue;
					}

					// Get result values.
					value += pvalue.value;
					hvalue += pvalue.h.value;
					let nl_index = pvalue.nl_index;

					// Reset index.
					i = nl_index;
				} else {
					// Append character to current value string.
					value += char;
					hvalue += char;
				}
			} else if (state === "command") {
				// Run command flag parser from here...
				let pvalue = pcommandflag({
					str: [i + "", string, string.length], // Provide new string information.
					vsi, // Value start index.
					type
				});

				// Join warnings.
				if (pvalue.warnings.length) {
					warnings = warnings.concat(pvalue.warnings);
				}
				// If error exists return error.
				if (pvalue.code) {
					return pvalue;
				}

				// Reset indices.
				ci = pvalue.ci;
				i = pvalue.index;

				// Build string value.
				value = `$(${pvalue.cmd_str})`;
				hvalue = `$(${pvalue.h.hcmd_str})`;

				// Reset delimiter count/index.
				delimiter_count = 0;
				indices.delimiter.last = null;

				// Check for duplicate values.
				isdupeval(value, ci, hvalue);

				// Reset state
				state = "delimiter";
				// Store value.
				args.push(value);
				// Add highlighted version.
				hargs.push(hvalue);

				// Clear value.
				value = "";
				hvalue = "";

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

		// Check for duplicate values.
		isdupeval(value, ci);

		args.push(value);
		// Add highlighted version.
		hargs.push(hvalue);
		// Reset value.
		value = "";
		hvalue = "";
	}

	// If arguments array is empty then nothing was parsed. Meaning no
	// arguments were provided.
	if (!args.length) {
		// Reset index.
		ci = vsi;

		// Add warning.
		issue("warning", 10);
	}

	// Return relevant parsing information.
	return {
		index: i,
		string,
		value,
		special: isvspecial,
		nl_index,
		warnings,
		args,
		h: {
			// Highlight option list values.
			args: h(hargs, "cmd-flag", ":/1")
		}
	};
};
