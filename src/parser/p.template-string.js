"use strict";

// Require needed modules.
const issuefunc = require("./p.error.js");
// Get RegExp patterns.
let { r_nl } = require("./h.patterns.js");

/**
 * Parses flag set line to extract flag name, value, and its other components.
 *
 * ---------- Parsing States Breakdown -----------------------------------------
 * ${ variable }
 *   |        |
 *   ^--------^-Whitespace-Boundary 1/2
 * ^-Symbol
 *    ^-Name  ^-Closing-Brace
 * -----------------------------------------------------------------------------
 *
 * @param  {string} string - The line to parse.
 * @return {object} - Object containing parsed information.
 */
module.exports = (params = {}) => {
	// Trace parser.
	require("./h.trace.js")(__filename);

	// Get params.
	let { str = [], vsi } = params;

	// Get globals.
	let string = str[1] || global.$app.get("string");
	let i = +(str[0] || global.$app.get("i"));
	let l = str[2] || global.$app.get("l");
	// let line_num = global.$app.get("line_num");
	// let line_fchar = global.$app.get("line_fchar");
	let h = global.$app.get("highlighter");
	let variables = global.$app.get("variables");
	let formatting = global.$app.get("formatting");

	// Parsing vars.
	// Note: Parsing the value starts a new loop from 0 to only focus on
	// parsing the provided value. This means the original loop index
	// needs to be accounted for. This variable will track the original
	// index.
	let ci = vsi;
	let value = "$";
	let name = "";
	let state = "tstring-open-brace"; // Parsing state.
	let nl_index;
	// Collect all parsing warnings.
	let warnings = [];
	// Capture state's start/end indices.
	let indices = {
		value: {
			start: null,
			end: null
		},
		"template-string": {
			open: null,
			variable: {
				start: null,
				end: null
			},
			close: null
		}
	};

	// Wrap issue function to add fixed parameters.
	let issue = (type = "error", code, char = "") => {
		// Run and return issue.
		return issuefunc(i, __filename, warnings, state, type, code, {
			// Parser specific variables.
			ci,
			char,
			name
		});
	};

	// Keep a list of unique loop iterations for current index.
	let last_index;

	// Loop over string.
	for (; i < l; i++) {
		// Cache current loop item.
		let char = string.charAt(i);
		// let pchar = string.charAt(i - 1);
		// let nchar = string.charAt(i + 1);

		// Note: Since loop logic can back track (e.g. 'i--;'), we only
		// increment current index (original index) on unique iterations.
		if (last_index !== i) {
			// Update last index to the latest unique iteration index.
			last_index = i;
			// Increment current index.
			ci += 1;
		}

		// End loop on a new line char.
		if (r_nl.test(char)) {
			// Store newline index.
			nl_index = i;
			break;
		}

		if (state === "tstring-open-brace") {
			if (char !== "{") {
				return issue("error", 2, char);
			}

			// Store index.
			indices.value.end = ci;
			value += char;

			// Set new state.
			state = "tstring-wsb";
		} else if (state === "tstring-wsb") {
			if (/[ \t]/.test(char)) {
				continue;
			} else if (!/[_a-zA-Z]/.test(char)) {
				// Variable must start with a letter or underscore.
				return issue("error", 3, char);
			}

			// Store index.
			indices["template-string"].variable.start = ci;

			// Set state to start grabbing variable name.
			state = "tstring-value";
			i--;
		} else if (state === "tstring-value") {
			if (/[_a-zA-Z]/.test(char)) {
				// Store index.
				indices["template-string"].variable.end = ci;
				name += char;

				// Store index.
				indices.value.end = ci;
				value += char;
			} else {
				state = "tstring-value-wsb";
				i--;
			}
		} else if (state === "tstring-value-wsb") {
			// End if character is a space.
			if (/[ \t]/.test(char)) {
				continue;
			} else {
				// Set state to closing.
				state = "tstring-value-end";
				i--;
			}
		} else if (state === "tstring-value-end") {
			if (char === "}") {
				// Close template state and revert back to value state.
				state = "value";
				// Store index.
				indices["template-string"].close = ci;

				// Store index.
				indices.value.end = ci;
				value += char;

				// Set stopped index.
				nl_index = i;
				// Return from parser as template-string parsing is complete.
				break;
			} else {
				// Anything other than '}' is invalid so return an error.
				return issue("error", 2, char);
			}
		}
	}

	// Lookup variable's value.
	let lookup = variables[`$${name}`];

	// Check that variable exists here.
	if (!lookup) {
		// Reset index to point to original index.
		ci = indices["template-string"].variable.start;

		return issue("error", 9, void 0);
	}

	// If not formatting then reset variable to actual value.
	if (!formatting) {
		value = lookup;
	}

	// Track used count.
	let used_counter = variables.__used__[name];
	variables.__used__[name] = used_counter + 1;

	// Return relevant parsing information.
	return {
		value,
		name,
		index: i,
		ci,
		warnings,
		nl_index,
		h: {
			// The highlighted string.
			value: !formatting
				? value
				: h("${", "keyword") + h(name, "variable") + h("}", "keyword")
		}
	};
};
