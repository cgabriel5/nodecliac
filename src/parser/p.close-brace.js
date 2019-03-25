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
module.exports = (...args) => {
	// Get arguments.
	let [string, i, l, line_num, line_fchar] = args;

	// Parsing vars.
	let state = "eol-wsb"; // Parsing state.
	let nl_index;
	// Collect all parsing warnings.
	let warnings = [];
	// Capture state's start/end indices.
	let indices = {
		brace: {
			close: i
		}
	};

	// Get RegExp patterns.
	let { r_nl } = require("./regexpp.js");

	// Generate issue with provided information.
	let issue = (type = "error", code, char = "") => {
		// Replace whitespace characters with their respective symbols.
		char = char.replace(/ /g, "␣").replace(/\t/g, "⇥");

		// Parsing error reasons.
		let reasons = {
			1: `Unexpected character '${char}'.`
		};

		// Generate base issue object.
		let issue_object = {
			line: line_num,
			index: i - line_fchar + 1, // Add 1 to account for 0 index.
			reason: reasons[code]
		};

		// Add additional information if issuing an error and return.
		if (type === "error") {
			return Object.assign(issue_object, {
				char,
				code,
				state,
				warnings
			});
		} else {
			// Add warning to warnings array.
			warnings.push(issue_object);
		}
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
