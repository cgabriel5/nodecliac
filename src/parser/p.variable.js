"use strict";

// Get needed modules.
const issuefunc = require("./p.error.js");
const ptemplatestr = require("./p.template-string.js");
// Get RegExp patterns.
let { r_schars, r_nl } = require("./h.patterns.js");

/**
 * Parses variables line to extract variable name and its value.
 *
 * ---------- Parsing States Breakdown -----------------------------------------
 * $variable = "value"
 *         | |       ^-EOL-Whitespace-Boundary 3
 *         ^-^-Whitespace-Boundary 1/2
 * ^-Symbol
 *  ^-Name
 *          ^-Assignment
 *            ^-Value
 * -----------------------------------------------------------------------------
 *
 * @param  {string} string - The line to parse.
 * @return {object} - Object containing parsed information.
 */
module.exports = () => {
	// Trace parser.
	require("./h.trace.js")(__filename);

	// Get globals.
	let string = global.$app.get("string");
	let i = global.$app.get("i");
	let l = global.$app.get("l");
	let line_num = global.$app.get("line_num");
	let line_fchar = global.$app.get("line_fchar");
	let h = global.$app.get("highlighter");
	let variables = global.$app.get("variables");
	let formatting = global.$app.get("formatting");

	// Parsing vars.
	let name = "$";
	let assignment = "";
	let value = "";
	let hvalue = ""; // Highlighted version.
	let qchar; // String quote char.
	let state = "name"; // Parsing state.
	let nl_index;
	// Collect all parsing warnings.
	let warnings = [];
	// Capture state's start/end indices.
	let indices = {
		symbol: {
			index: i
		},
		name: {
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
			name
		});
	};

	// Increment index by 1 to skip initial '$' variable symbol.
	i++;

	// Loop over string.
	for (; i < l; i++) {
		// Cache current loop item.
		let char = string.charAt(i);
		let pchar = string.charAt(i - 1);
		let nchar = string.charAt(i + 1);

		// End loop on a new line char.
		if (r_nl.test(char)) {
			// Store newline index.
			nl_index = i;
			break;
		}

		// Default parse state to 'name' (l → r : $name=value).
		if (state === "name") {
			// If char is the first char...
			if (name.length === 1) {
				// First char of name must be a letter or underscore.
				if (!/[_a-zA-Z]/.test(char)) {
					return issue("error", 1, char);
				}
				// Store index.
				indices.name.start = i;
				indices.name.end = i;
				name += char;
			}
			// Keep building name string...
			else {
				// If char is allowed keep building string.
				if (/[_a-zA-Z0-9]/.test(char)) {
					// Store index.
					indices.name.end = i;
					name += char;
				}
				// If char is an eq sign change state/reset index.
				else if (char === "=") {
					state = "assignment";
					i--;
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
			indices.assignment.index = i;

			assignment = "=";

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
				} else if (!/[a-zA-Z0-9]/.test(char)) {
					return issue("error", 3, char);
				}

				// Store index.
				indices.value.start = i;
				value += char;
				hvalue += char;
			} else {
				// If value is a quoted string we allow for anything.
				// End string at same style-unescaped quote.
				if (qchar) {
					if (char === qchar && pchar !== "\\") {
						state = "eol-wsb";
					}

					// Store index.
					indices.value.end = i;

					// Check for template strings (variables).
					if (char === "$" && pchar !== "\\" && nchar === "{") {
						// Run template-string parser from here...
						let pvalue = ptemplatestr({
							str: [i + 1] // Index to resume parsing at.
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

						// Reset oneliner start index.
						i = nl_index;
					} else {
						// Else keep building value string.
						value += char;
						hvalue += char;
					}
				} else {
					// We must stop at the first space char.
					if (/[ \t]/.test(char)) {
						state = "eol-wsb";
						i--;
					} else {
						// When building unquoted "strings" warn user
						// when using unescaped special characters.
						if (r_schars.test(char)) {
							issue("warning", 5, char);
						}

						// Store index.
						indices.value.end = i;
						value += char;
						hvalue += char;
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

	// Check for dangling '$'.
	if (name === "$") {
		// Reset index so it points to '$' symbol.
		i = indices.symbol.index;

		return issue("error", 2, "$");
	}

	// If value exists and is quoted, check that is properly quoted.
	if (qchar) {
		// If building quoted string check if it's closed off.
		if (value.charAt(value.length - 1) !== qchar) {
			// Set index to first quote.
			i = indices.value.start;

			return issue("error", 4);
		}
	}

	// If assignment but not value give warning.
	if (assignment && !value) {
		// Reset index to point to eq sign.
		i = indices.assignment.index;

		// Add warning.
		issue("warning", 6, "=");
	}

	// If no value was provided give warning.
	if (!assignment) {
		// Reset index to point to original index.
		i = indices.name.end;

		// Add warning.
		issue("warning", 8, "=");
	}

	// If variable exists give an dupe/override warning.
	if (variables.hasOwnProperty(name)) {
		// Reset index to point to name.
		i = indices.name.end;

		issue("warning", 7, "=");
	}

	if (!formatting) {
		// Unquote value. [https://stackoverflow.com/a/19156197]
		value = value.replace(/^(["'])(.+(?=\1$))\1$/, "$2");
		hvalue = hvalue.replace(/^(["'])(.+(?=\1$))\1$/, "$2");
	}

	// Store where variable was declared.
	variables.__defs__[name.slice(1)] = [line_num, 0];

	// Return relevant parsing information.
	return {
		name,
		value,
		nl_index,
		warnings,
		h: {
			// Add syntax highlighting.
			name: h(name, "variable"),
			value: h(hvalue, "value")
		}
	};
};
