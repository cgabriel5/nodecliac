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
module.exports = (string, offset) => {
	// Vars.
	let i = offset || 0;
	let l = string.length;

	// Parsing vars.
	let state = "eol-wsb"; // Parsing state.
	let nl_index;
	// Collect all parsing warnings.
	let warnings = [];
	// Capture state's start/end indices.
	let indices = {
		brace: {
			close: offset
		}
	};

	// Get RegExp patterns.
	let { r_nl } = require("./regexpp.js");

	// Generate error with provided information.
	let error = (char = "", code) => {
		// Replace whitespace characters with their respective symbols.
		char = char.replace(/ /g, "␣").replace(/\t/g, "⇥");

		// Parsing error reasons.
		let reasons = {
			1: `Unexpected character '${char}'.`
		};

		// Return object containing relevant information.
		return {
			index: i,
			offset,
			char,
			code,
			state,
			reason: reasons[code],
			warnings
		};
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
				return error(char, 1);
			}
		}
	}

	// Return relevant parsing information.
	return { index: i, offset, nl_index, warnings };
};
