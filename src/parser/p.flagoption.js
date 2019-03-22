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
	let name = "";
	let boundary = "";
	let assignment = "";
	let value = "";
	let qchar; // String quote char.
	let state = "boundary"; // Parsing state.
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
	let error = (char = "", code) => {
		// Replace whitespace characters with their respective symbols.
		char = char.replace(/ /g, "␣").replace(/\t/g, "⇥");

		// Parsing error reasons.
		let reasons = {
			0: "Unexpected token '-'.",
			// 2: `Unexpected character '${char}'.`,
			4: `Improperly closed string.`
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

	// Increment index by 1 to skip initial '-' setting symbol.
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

		// Default parse state.
		if (state === "boundary") {
			// Boundary must only contain whitespace.
			if (/[ \t]/.test(char)) {
				if (!boundary) {
					// Store start index.
					indices.boundary.start = i;
				}

				// Store index.
				indices.boundary.end = i;
				boundary += char;
			} else {
				// Store index.
				indices.value.start = i;
				state = "value";
				i--;
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

	// Check for dangling '-'.
	if (!value[0]) {
		// Reset index so it points to '-' symbol.
		i = indices.symbol.index;

		return error("-", 0);
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

	// Return relevant parsing information.
	return { index: i, offset, name, value, assignment, nl_index, warnings };
};
