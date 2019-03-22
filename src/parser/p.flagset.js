// Require needed modules.
const pflagvalue = require("./p.flag-value.js");

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
module.exports = (string, offset, indentation) => {
	// Vars.
	let i = offset || 0;
	let l = string.length;

	// Parsing vars.
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
	// Capture state's start/end indices.
	let indices = {
		symbol: {
			index: offset
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
		}
	};

	// Get RegExp patterns.
	let { r_schars, r_nl } = require("./regexpp.js");

	// Generate error with provided information.
	let error = (char = "", code, index) => {
		// Use loop index if one is not provided.
		index = index || i;

		// Replace whitespace characters with their respective symbols.
		char = char.replace(/ /g, "␣").replace(/\t/g, "⇥");

		// Parsing error reasons.
		let reasons = {
			1: `Setting started with '${char}'. Expected a letter.`,
			2: `Unexpected character '${char}'.`,
			3: `Value cannot start with '${char}'.`,
			4: `Improperly closed string.`,
			5: `Unescaped character '${char}' in value.`,
			6: `Empty flag assignment.`,
			8: `Empty flag '${name}'.`,
			9: `${
				isvspecial === "command" ? "Command-flag" : "Options flag list"
			} missing closing ')'.`
		};

		// Return object containing relevant information.
		return {
			index,
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

		if (state === "symbol") {
			if (char === "-") {
				if (symbol.length <= 2) {
					symbol += char;
				}
			}
			// Hitting anything other than a hyphen ends symbol state.
			else {
				state = "name";
				// Reset index.
				i--;

				// Before ending state check symbol.
				if (!/-{1,2}/.test(symbol)) {
					// Reset index.
					i = offset;
					return error(char, 2);
				}
			}
			// Default parse state to 'name' (l → r : @name=value).
		} else if (state === "name") {
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
			// following: ", ', or a-zA-Z0-9
			if (value === "") {
				if (/["']/.test(char)) {
					qchar = char;
				}
				// Command-flag or options list.
				else if (/[\$\(]/.test(char)) {
					isvspecial = char === "$" ? "command" : "list";

					if (char === "$" && nchar !== "(") {
						return error(char, 2);
					}
				}
				// For anything else give an error.
				else if (!/[a-zA-Z0-9]/.test(char)) {
					return error(char, 3);
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

	// Check that command-flag/options list is properly closed.
	if (isvspecial) {
		if (value.length > 1) {
			if (value.charAt(value.length - 1) !== ")") {
				return error(void 0, 9);
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
			return error(void 0, 4, indices.value.start);
		}
	}

	// // If assignment but not value give warning.
	// if (assignment && !value) {
	// 	// Provide eq sign index.
	// 	warnings.push(error("=", 6, indices.assignment.start));
	// }

	// If no value was provided give warning.
	if (!assignment && !indices.name.boolean) {
		// Provide original index.
		warnings.push(error("=", 8, indices.name.end));
	}

	// Further parse value if not an opening parentheses.
	if (value !== "(") {
		let pvalue = pflagvalue(
			value,
			0,
			isvspecial,
			// Provide the index where the value starts - the initial
			// loop index position plus the indentation length to
			// properly provide correct line error/warning output.
			indices.value.start - offset + indentation.length
		);

		// Reset value.
		value = pvalue.args;
		// Reset index. Combine indices.
		i += pvalue.index;

		// Join warnings.
		if (pvalue.warnings.length) {
			warnings = warnings.concat(pvalue.warnings);
		}
		// If error exists return error.
		if (pvalue.code) {
			return pvalue;
		}
	} else {
		// Since value is '(' we set flag and reset value.
		isopeningpr = true;
		value = [value];
	}

	// Return relevant parsing information.
	return {
		index: i,
		offset,
		symbol,
		name,
		value,
		special: isvspecial,
		assignment,
		nl_index,
		warnings,
		isopeningpr
	};
};
