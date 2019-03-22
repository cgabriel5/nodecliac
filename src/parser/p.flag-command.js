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
module.exports = (string, offset, type, voffset) => {
	// Vars.
	let i = offset || 0;
	let l = string.length;

	// If parsing a list reduce length to ignore closing ')'. Otherwise,
	// leave length be as a command, for example, does get wrapped with '()'.
	if (type === "list") {
		l--;
	}

	// Parsing vars.
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

	// Generate error with provided information.
	let error = (char = "", code) => {
		// Use loop index if one is not provided.
		index = index || i + voffset;

		// Replace whitespace characters with their respective symbols.
		char = char.replace(/ /g, "␣").replace(/\t/g, "⇥");

		// Parsing error reasons.
		let reasons = {
			2: `Unexpected character '${char}'.`,
			3: `Value cannot start with '${char}'.`,
			4: `Improperly closed string.`,
			5: `Empty command flag argument.`,
			6: `Improperly closed command-flag. Missing ')'.`
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

	// Loop over string.
	for (; i < l; i++) {
		// Cache current loop item.
		let char = string.charAt(i);
		let pchar = string.charAt(i - 1);
		let nchar = string.charAt(i + 1);

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
					return error(char, 5);
				}
				// Increment delimiter counter.
				delimiter_count++;

				// Store delimiter index.
				indices.delimiter.last = i;

				i--;
			} else if (char === ")") {
				state = "closing-parens";
				i--;
			} else {
				// If char is anything other than q quote or a comma
				// the character is not allowed so return an error.
				if (!/[ \t]/.test(char)) {
					return error(char, 2);
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
						return error(char, 4);
					}
				}

				// Append character to current value string.
				value += char;
			} else if (state === "closing-parens") {
				// Make a final check. The char after the closing ')'
				// has to be an end-of-line character or a space.
				if (nchar && !/[ \t\)]/.test(nchar)) {
					return error(nchar, 2);
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
		return error(void 0, 6);
	}

	// If the delimiter index remained then there is a trailing delimiter.
	if (indices.delimiter.last) {
		i = indices.delimiter.last;
		return error(void 0, 5);
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
		index: i,
		offset,
		cmd_str,
		warnings
	};
};
