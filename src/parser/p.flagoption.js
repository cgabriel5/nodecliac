// Require needed modules.
const pflagvalue = require("./p.flag-value.js");

/**
 * Parses flag option line.
 *
 * ---------- Parsing States Breakdown -----------------------------------------
 * - value
 *  |     ^-EOL-Whitespace-Boundary 2
 *  ^-Whitespace-Boundary 1
 * ^-Symbol
 *  ^-Value
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
	let boundary = "";
	let assignment = "";
	let value = "";
	let qchar; // String quote char.
	let state = "symbol"; // Parsing state.
	let nl_index;
	// Collect all parsing warnings.
	let warnings = [];
	// Capture state's start/end indices.
	let indices = {
		symbol: {
			index: offset
		},
		boundary: {
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
	let error = (char = "", code, index) => {
		// Use loop index if one is not provided.
		index = (index || i) + indentation.length;

		// Replace whitespace characters with their respective symbols.
		char = char.replace(/ /g, "␣").replace(/\t/g, "⇥");

		// Parsing error reasons.
		let reasons = {
			0: `Empty flag option.`,
			// 2: `Unexpected character '${char}'.`,
			3: `Invalid flag option.`,
			4: `Improperly closed string.`
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

		// Default parse state.
		if (state === "symbol") {
			// Check that first char is indeed a hyphen symbol '-'.
			if (char !== "-") {
				return error(char, 3);
			}

			// Store index.
			indices.symbol.index = i;
			state = "boundary";
			symbol = char;
		} else if (state === "boundary") {
			// Boundary must contain at least a single whitespace char.
			if (boundary === "") {
				// First boundary char must be space.
				if (/[ \t]/.test(char)) {
					// Store indices.
					indices.boundary.start = i;
					indices.boundary.end = i;

					boundary += char;
				} else {
					// If first char is not a whitespace give an error.
					return error(char, 3);
				}
			} else {
				// Only whitespace.
				if (/[ \t]/.test(char)) {
					// Store index.
					indices.boundary.end = i;
					boundary += char;
				} else {
					// Store index.
					indices.value.start = i;
					state = "value";
					i--;
				}
			}
		} else if (state === "value") {
			value += char;
		}
	}

	let type;
	// Determine value type.
	if (value.charAt(0) === "$") {
		type = "command";
	} else if (/^["']/.test(value)) {
		type = ":quoted";
	} else {
		type = ":escaped";
	}

	// If option does not exist then value will be empty (dangling '-').
	if (!value) {
		// Reset index so it points to '-' symbol.
		warnings.push(error("-", 0, indices.symbol.index));
	} else {
		// Run flag value parser from here...
		let pvalue = pflagvalue(
			value,
			0,
			type,
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

		// If value exists and is quoted, check that is properly quoted.
		if (type === ":quoted") {
			// If building quoted string check if it's closed off.
			if (value[0].charAt(value[0].length - 1) !== value[0].charAt(0)) {
				// Set index to first quote.
				i = indices.value.start;

				return error(void 0, 4);
			}
		}
	}

	// Return relevant parsing information.
	return { index: i, offset, symbol, value, assignment, nl_index, warnings };
};
