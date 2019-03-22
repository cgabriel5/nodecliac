// Require needed modules.
const pcommandflag = require("./p.flag-command.js");

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
module.exports = (string, offset, type, voffset) => {
	// Vars.
	let i = offset || 0;
	let l = string.length;

	// Modify index/string length when parsing a command-flag/lists to
	// ignore '$(/(', ')' syntax.
	if (type && !type.startsWith(":")) {
		if (type === "command") {
			// i += 2;
		} else {
			// Increment index by one to avoid list starting at '('.
			i++;
			// Decrease length by 1 to skip closing ')'.
			l--;
		}
	}

	// Parsing vars.
	let value = "";
	let qchar; // String quote char.
	let isvspecial;
	let state = ""; // Parsing state.
	let nl_index;
	// Collect all parsing warnings.
	let warnings = [];
	let args = [];

	// Reset parsing state when type provided from flag options script.
	if (type && type.startsWith(":")) {
		if (type !== ":command") {
			state = type.slice(1);
		} else {
			type = "command";
		}
	}

	// Get RegExp patterns.
	let { r_schars, r_nl } = require("./regexpp.js");

	// Generate error with provided information.
	let error = (char = "", code, index) => {
		// Use loop index if one is not provided.
		index = index || i + voffset;

		// Replace whitespace characters with their respective symbols.
		char = char.replace(/ /g, "␣").replace(/\t/g, "⇥");

		// Parsing error reasons.
		let reasons = {
			2: `Unexpected character '${char}'.`,
			4: `Improperly closed string.`,
			5: `Unescaped character '${char}' in value.`,
			10: `Empty '()' (no flag options).`
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

	// command-flag, quoted, regular (escaped value)

	// Loop over string.
	for (; i < l; i++) {
		// Cache current loop item.
		let char = string.charAt(i);
		let pchar = string.charAt(i - 1);
		let nchar = string.charAt(i + 1);

		// Determine the initial parsing state.
		if (!state) {
			// Ignore everything but the following starting characters:
			// command-flag: $(
			// quoted: "  or '
			// normal: anything but unescaped whitespace.
			if (char === "$") {
				if (nchar === "(") {
					state = "command";
					// Reset index to account for '('.
					i++;
					continue;
				} else {
					// If the next char is not '(' return error.
					return error(char, 2);
				}
			} else if (/["']/.test(char)) {
				state = "quoted";
				qchar = char;
			} else {
				state = !/[ \t,]/.test(char) ? "escaped" : "delimiter";
				i--;
			}
		} else {
			if (state === "delimiter") {
				state = "";
			} else if (state === "escaped") {
				// Build value until an unescaped whitespace char is hit.
				if (/[ \t]/.test(char) && pchar !== "\\") {
					// Reset state
					state = "";
					// Store value.
					args.push(value);
					// Clear value.
					value = "";
					// Reset index to set delimiter state.
					i--;
					continue;
				}
				// When building unquoted "strings" warn user
				// when using unescaped special characters.
				if (r_schars.test(char) && pchar !== "\\") {
					warnings.push(error(char, 5));
				}

				// Append character to current value string.
				value += char;
			} else if (state === "quoted") {
				if (char === qchar && pchar !== "\\") {
					// Reset state
					state = "";
					// Store value.
					args.push(`${qchar}${value}${qchar}`);
					// Clear value.
					value = "";
					continue;
				}

				// Check that string was properly closed.
				if (i === l) {
					if (value.charAt(value.length - 1) !== qchar) {
						// String was never closed so give error.
						return error(char, 4);
					}
				}

				// Append character to current value string.
				value += char;
			} else if (state === "command") {
				// Delimiter is a comma.
				let pvalue = pcommandflag(
					string,
					i,
					type,
					// Provide the index where the value starts - the initial
					// loop index position plus the indentation length to
					// properly provide correct line error/warning output.
					// indices.value.start - offset + indentation.length
					voffset
				);

				// Join warnings.
				if (pvalue.warnings.length) {
					warnings = warnings.concat(pvalue.warnings);
				}
				// If error exists return error.
				if (pvalue.code) {
					return pvalue;
				}

				// Reset state
				state = "";
				// Store value.
				args.push(`$(${pvalue.cmd_str})`);
				// Clear value.
				value = "";

				// Reset index.
				i = pvalue.index;
				continue;
			}
		}
	}

	// Add final value if it exists.
	if (value) {
		args.push(value);
		// Reset value.
		value = "";
	}

	// If args array is empty then no arguments were parsed meaning no
	// arguments were provided.
	if (!args.length) {
		warnings.push(error(void 0, 10, voffset));
	}

	// Return relevant parsing information.
	return {
		string,
		index: i,
		offset,
		value,
		special: isvspecial,
		nl_index,
		warnings,
		args
	};
};
