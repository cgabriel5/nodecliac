/**
 * Parses settings line to extract setting name and its value.
 *
 * ---------- Parsing States Breakdown -----------------------------------------
 * @default = true
 *         | |    ^-EOL-Whitespace-Boundary 3
 *         ^-^-Whitespace-Boundary 1/2
 * ^-Symbol
 *  ^-Name
 *          ^-Assignment
 *            ^-Value
 * -----------------------------------------------------------------------------
 *
 * @param  {string} string - The setting line.
 * @return {object} - Object containing setting name, value, and warnings.
 */
module.exports = (string, offset, settings) => {
	// Vars.
	let i = offset || 0;
	let l = string.length;

	// Parsing vars.
	let name = "@";
	let assignment = "";
	let value = "";
	let qchar; // String quote char.
	let state = "name"; // Parsing state.
	let nl_index;
	// Collect all parsing warnings.
	let warnings = [];
	// Capture state's start/end indices.
	let indices = {
		symbol: {
			index: offset
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

	// Get RegExp patterns.
	let { r_schars, r_nl } = require("./regexpp.js");

	// Generate error with provided information.
	let error = (char = "", code) => {
		// Replace whitespace characters with their respective symbols.
		char = char.replace(/ /g, "␣").replace(/\t/g, "⇥");

		// Parsing error reasons.
		let reasons = {
			0: "Unexpected token '@'.",
			1: `Setting started with '${char}'. Expected a letter.`,
			2: `Unexpected character '${char}'.`,
			3: `Value cannot start with '${char}'.`,
			4: `Improperly closed string.`,
			5: `Unescaped character '${char}' in value.`,
			6: `Empty setting assignment.`,
			7: `Duplicate setting '${name}'.`,
			8: `Empty setting '${name}'.`
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

	// Increment index by 1 to skip initial '@' setting symbol.
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

		// Default parse state to 'name' (l → r : @name=value).
		if (state === "name") {
			// If char is the first char...
			if (name.length === 1) {
				// First char of name must be a letter.
				if (!/[a-zA-Z]/.test(char)) {
					return error(char, 1);
				}
				// Store index.
				indices.name.start = i;
				name += char;
			}
			// Keep building name string...
			else {
				// If char is allowed keep building string.
				if (/[-_a-zA-Z]/.test(char)) {
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
					return error(char, 2);
				}
			}
		} else if (state === "name-wsb") {
			// If the character is not a space and the assignment has not
			// been set we are looking for an eq sign.
			if (!/[ \t]/.test(char) && assignment === "") {
				if (char !== "=") {
					return error(char, 2);
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
					return error(char, 3);
				}

				// Store index.
				indices.value.start = i;
				value += char;
			} else {
				// If value is a quoted string we allow for anything.
				// End string at same style-unescaped quote.
				if (qchar) {
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
							warnings.push(error(char, 5));
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
				return error(char, 2);
			}
		}
	}

	// Check for dangling '@'.
	if (name === "@") {
		// Reset index so it points to '@' symbol.
		i = indices.symbol.index;

		return error("@", 0);
	}

	// If value exists and is quoted, check that is properly quoted.
	if (qchar) {
		// If building quoted string check if it's closed off.
		if (value.charAt(value.length - 1) !== qchar) {
			// Set index to first quote.
			i = indices.value.start;

			return error(void 0, 4);
		}
	}

	// If assignment but not value give warning.
	if (assignment && !value) {
		// Reset index to point to eq sign.
		i = indices.assignment.index;

		// Add warning.
		warnings.push(error("=", 6));
	}

	// If no value was provided give warning.
	if (!assignment) {
		// Reset index to point to original index.
		i = indices.name.end;

		// Add warning.
		warnings.push(error("=", 8));
	}

	// If setting exists give an dupe/override warning.
	if (settings.hasOwnProperty(name)) {
		// Reset index to point to name.
		i = indices.name.end;

		warnings.push(error("=", 7));
	}

	// Return relevant parsing information.
	return { index: i, offset, name, value, assignment, nl_index, warnings };
};
