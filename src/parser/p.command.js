/**
 * Parses command chain line to extract command chain.
 *
 * ---------- Parsing States Breakdown -----------------------------------------
 * program.command = [ ]?
 *                | |
 *                ^-^-Whitespace-Boundary 1/2
 * ^-Command-Chain
 *                 ^-Assignment
 *                   ^-Opening-Bracket
 *                    ^-Whitespace-Boundary 3
 *                     ^-Optional-Closing-Bracket?
 *                      ^-EOL-Whitespace-Boundary 4
 * -----------------------------------------------------------------------------
 *
 * @param  {string} string - The setting line.
 * @return {object} - Object containing setting name, value, and warnings.
 */
module.exports = (string, offset) => {
	// Vars.
	let i = offset || 0;
	let l = string.length;

	// Parsing vars.
	let chain = "";
	let escaping;
	let isshortcut;
	let assignment = "";
	let value = "";
	let flagset = "";
	let flagsets = [];
	let state = "chain"; // Parsing state.
	let nl_index;
	// Collect all parsing warnings.
	let warnings = [];
	// Capture state's start/end indices.
	let indices = {
		chain: {
			start: offset,
			end: null
		},
		assignment: {
			index: null
		},
		value: {
			start: null,
			end: null
		},
		braces: {
			open: null
		}
	};
	// Store brace state (open/closed).
	let brstate;

	// Get RegExp patterns.
	let { r_nl } = require("./regexpp.js");

	// Generate error with provided information.
	let error = (char = "", code) => {
		// Replace whitespace characters with their respective symbols.
		char = char.replace(/ /g, "␣").replace(/\t/g, "⇥");

		// Parsing error reasons.
		let reasons = {
			1: `Chain started with '${char}'. Expected a letter.`,
			2: `Unnecessary escape character. \\${char}.`,
			3: `Illegal escape sequence \\${char}.`,
			4: `Unexpected character '${char}'.`,
			5: `Empty command chain assignment.`,
			6: `Empty '[]' (no flags).`
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

		// End loop on a new line char.
		if (r_nl.test(char)) {
			// Store newline index.
			nl_index = i;
			break;
		}

		// Default parse state to 'chain'.
		if (state === "chain") {
			// If char is the first char...
			if (!chain) {
				// First char of chain must be a letter.
				if (!/[a-zA-Z]/.test(char)) {
					return error(char, 1);
				}
				// Store index.
				indices.chain.start = i;
				chain += char;
			}
			// Keep building chain string...
			else {
				// If char is allowed keep building string.
				if (/[-_.\\\/\{\}a-zA-Z0-9]/.test(char)) {
					let skip = false;

					// Check for escape char  '\'. Next char must be a dot.
					if (!escaping) {
						if (char === "\\") {
							escaping = true;
						}
					}
					if (escaping) {
						// Check if char actually needs to be escaped.
						if (nchar !== ".") {
							// Must be an allowed character.
							if (/[-_a-zA-Z0-9]/.test(nchar)) {
								// If char is not a dot give warning.
								warnings.push(error(nchar, 2));
								skip = true;
							} else {
								return error(nchar, 3);
							}
						}
						// Turn off flag.
						escaping = false;
					}

					// // Check for shortcut curly braces.
					// if (char === "{") {
					// 	if (!isshortcut) {
					// 		isshortcut = true;
					// 	}
					// }

					// Store index.
					indices.chain.end = i;
					if (!skip) {
						chain += char;
					}
				}
				// If char is an eq sign change state/reset index.
				else if (char === "=") {
					state = "assignment";
					i--;
				}
				// If we encounter a whitespace character, everything after
				// this point must be a space until we encounter an eq sign
				// or the end-of-line.
				else if (/[ \t]/.test(char) && (!escaping && !isshortcut)) {
					state = "chain-wsb";
					continue;
				}
				// Anything else the character is not allowed.
				else {
					return error(char, 4);
				}
			}
		} else if (state === "chain-wsb") {
			// If the character is not a space and the assignment has not
			// been set we are looking for an eq sign.
			if (!/[ \t]/.test(char) && assignment === "") {
				if (char !== "=") {
					return error(char, 4);
				} else {
					state = "assignment";
					i--;
				}
			}
		} else if (state === "assignment") {
			// Store index.
			indices.assignment.index = i;

			assignment = "=";

			state = "open-bracket-wsb";
		} else if (state === "open-bracket-wsb") {
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
			// If this is the first char is must be '['.
			if (value === "") {
				if (char === "[") {
					// Store index.
					indices.braces.open = i;
				} else if (char === "-") {
					// Parsing a one-line flag.
					state = "flagset-oneline";
					i--;
					continue;
				} else {
					return error(char, 4);
				}

				// Store index.
				indices.value.start = i;
				value += char;
			} else {
				// After getting the first character '[' everything after
				// must be a space followed by ']', whitespace, or nothing.
				if (char === "]") {
					state = "eol-wsb";
				} else if (!/[ \t]/.test(char)) {
					return error(char, 4);
				}

				// Store index.
				indices.value.end = i;
				// Don't add whitespace to value.
				if (!/[ \t]/.test(char)) {
					value += char;
				}
			}
		} else if (state === "eol-wsb") {
			// Allow trailing whitespace only.
			if (!/[ \t]/.test(char)) {
				return error(char, 4);
			}
		} else if (state === "flagset-oneline") {
			// With RegExp to parse on unescaped '|' characters it would be
			// something like this: String.split(/(?<=[^\\]|^|$)\|/);
			// [https://stackoverflow.com/a/25895905]
			// [https://stackoverflow.com/a/12281034]

			// Get individual flag sets. Use unescaped '|' as the delimiter.
			if (char === "|" && pchar !== "\\") {
				// [TODO] Run other checks on flag set.
				// Store current flag set.
				flagsets.push(flagset);
				// Reset flag set string.
				flagset = "";
			} else {
				// Build flag set string.
				flagset += char;
			}
		}
	}

	// Add final flag set.
	if (flagset) {
		flagsets.push(flagset);
		// Clear var.
		flagset = "";
	}

	// If there was assignment do some value checks.
	if (assignment && !flagsets.length) {
		// Determine brace state.
		brstate = value === "[]" ? "closed" : "open";

		// If assignment but not value give warning.
		if (!value) {
			// Reset index to point to eq sign.
			i = indices.assignment.index;

			// Add warning.
			warnings.push(error("=", 5));
		}

		// If assignment but not value give warning.
		if (brstate === "closed") {
			// Reset index to point to opening brace'['.
			i = indices.value.start;

			// Add warning.
			warnings.push(error(void 0, 6));
		}
	}

	// Return relevant parsing information.
	return {
		index: i,
		offset,
		chain,
		value,
		brstate,
		assignment,
		flagsets,
		nl_index,
		warnings
	};
};
