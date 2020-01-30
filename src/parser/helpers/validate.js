"use strict";

const error = require("./error.js");
const { r_quote } = require("./patterns.js");

/**
 * Performs checks on string as well as interpolates any variables.
 *
 * @param  {object} S - Main loop state object.
 * @param  {object} N - The node object.
 * @return {object} - Object containing parsed information.
 */
let validate = (S, N, type) => {
	let { value } = N.value;

	// If value doesn't exist or is '(' (long-form flag list) return.
	if (!value || value === "(") return;

	// Determine type if not provided.
	if (!type) {
		type = "escaped";
		let char = value.charAt(0);
		if (char === "$") type = "command-flag";
		else if (char === "(") type = "list";
		else if (r_quote.test(char)) type = "quoted";
	}

	// Get column index to resume error checks at.
	let resumepoint = N.value.start - S.tables.linestarts[S.line];
	resumepoint++; // Add 1 to account for 0 base indexing.

	/**
	 * Create temporary Node.
	 *
	 * @type {object} - The temp Node object.
	 */
	let tNode = (start, end, value) => ({ value: { start, end, value } });

	switch (type) {
		case "quoted":
			{
				// Error if improperly quoted.
				if (!/^\$?("|').*?\1$/.test(value)) {
					S.column = resumepoint;
					error(S, __filename, 10);
				}
				// Error it string is empty.
				if (/^("|')\1$/.test(value)) {
					S.column = resumepoint;
					error(S, __filename, 11);
				}

				// Interpolate variables.
				const r = /(?<!\\)\$\{\s*[^}]*\s*\}/g;
				value = value.replace(r, function(match, index) {
					match = match.replace(/^\$\{\s*|\s*\}$/g, "");

					// Don't interpolation if formatting.
					if (S.args.action === "format") return `\${${match}}`;

					let value = S.tables.variables[match];
					// Error if var is being used before declared.
					if (!value) {
						S.column = resumepoint + index;
						return error(S, __filename, 12);
					}

					return value;
				});

				N.args = [value];
				N.value.value = value;
			}

			break;

		case "escaped":
			N.args = [value];

			break;
		case "command-flag":
			{
				// Error if command-flag doesn't start with '$('.
				if (!/^\$\(/.test(value)) {
					S.column = resumepoint + 1;
					error(S, __filename, 13);
				}
				// Error if command-flag doesn't end with ')'.
				if (!/\)$/.test(value)) {
					S.column = resumepoint + value.length - 1;
					error(S, __filename, 13);
				}

				let argument = "";
				let args = [];
				let qchar;
				let delimiter_count = 0;
				let delimiter_index;
				let i = 2; // Offset to account for '$('.
				let resume_index = N.value.start + i;
				let vsi; // Index where value starts.

				// Ignore starting '$(' and ending ')' when looping.
				for (let l = value.length - 1; i < l; i++, resume_index++) {
					let char = value.charAt(i);
					let pchar = value.charAt(i - 1);
					let nchar = value.charAt(i + 1);

					if (!qchar) {
						// Look for unescaped quote characters.
						if (/["']/.test(char) && pchar !== "\\") {
							vsi = resume_index;
							qchar = char;
							argument += char;
						} else if (/[ \t]/.test(char)) {
							// Ignore any whitespace outside of quotes.
						} else if (char === ",") {
							// Track count of command delimiters.
							delimiter_count++;
							delimiter_index = i;

							// If delimiter count is >1, there are empty args.
							if (delimiter_count > 1 || !args.length) {
								S.column = resumepoint + i;
								error(S, __filename, 14);
							}
						}
						// Look for '$' prefixed strings.
						else if (char === "$" && /["']/.test(nchar)) {
							qchar = nchar;
							argument += `${char}${nchar}`;
							resume_index++;
							i++;
							vsi = resume_index;
						} else {
							// Note: Anything else isn't allowed. For example,
							// hitting this block means a character isn't
							// being quoted. Something like this can trigger
							// this block.
							// Example: $("arg1", "arg2", arg3 )
							// ---------------------------^ Value is unquoted.

							S.column = resumepoint + i;
							error(S, __filename);
						}
					} else {
						argument += char;

						if (char === qchar && pchar !== "\\") {
							let tN = tNode(vsi, argument.length - 1, argument);
							argument = validate(S, tN, "quoted");
							args.push(argument);

							argument = "";
							qchar = "";
							delimiter_index = null;
							delimiter_count = 0;
						}
					}
				}

				// If flag is still there is a trailing command delimiter.
				if (delimiter_index && !argument) {
					S.column = resumepoint + delimiter_index;
					error(S, __filename, 14);
				}

				// Get last argument.
				if (argument) {
					i--; // Reduce to account for last completed iteration.

					let tN = tNode(vsi, argument.length - 1, argument);
					argument = validate(S, tN, "quoted");
					args.push(argument);
				}

				let cvalue = `$(${args.join(",")})`; // Build clean cmd-flag.
				N.args = [cvalue];
				N.value.value = value = cvalue;
			}

			break;

		case "list":
			{
				// Error if list doesn't start with '('.
				if (!/^\(/.test(value)) {
					S.column = resumepoint;
					error(S, __filename, 15);
				}
				// Error if command-flag doesn't end with ')'.
				if (!/\)$/.test(value)) {
					S.column = resumepoint + value.length - 1;
					error(S, __filename, 15);
				}

				let argument = "";
				let args = [];
				let qchar;
				let mode;
				let i = 1; // Offset to account for '('.
				let resume_index = N.value.start + i;
				let vsi; // Index where value starts.

				// Ignore starting '(' and ending ')' when looping.
				for (let l = value.length - 1; i < l; i++, resume_index++) {
					let char = value.charAt(i);
					let pchar = value.charAt(i - 1);

					if (!mode) {
						// Skip unescaped ws delimiters.
						if (/[ \t]/.test(char) && pchar !== "\\") continue;

						// Set mode depending on the character.
						if (/["']/.test(char) && pchar !== "\\") {
							vsi = resume_index;
							mode = "quoted";
							qchar = char;
						} else if (char === "$" && pchar !== "\\") {
							vsi = resume_index;
							mode = "command-flag";
						} else if (!/[ \t]/.test(char)) {
							vsi = resume_index;
							mode = "escaped";
						}
						// All other characters are invalid so error.
						else {
							S.column = resumepoint + i;
							error(S, __filename);
						}

						// Note: If arguments array is already populated
						// and if the previous char is not a space then
						// the argument was not delimited so give an error.
						// Example:
						// subl.command = --flag=(1234 "ca"t"    $("cat"))
						// --------------------------------^ Error point.
						if (args.length && !/[ \t]/.test(pchar)) {
							S.column = resumepoint + i;
							error(S, __filename);
						}

						argument += char;
					} else if (mode) {
						if (mode === "quoted") {
							// Stop at same-style quote char.
							if (char === qchar && pchar !== "\\") {
								argument += char;

								let end = argument.length - 1;
								let tN = tNode(vsi, end, argument);
								argument = validate(S, tN, mode);
								args.push([argument, mode]);

								argument = mode = "";
								vsi = 0;
							} else argument += char;
						} else if (mode === "escaped") {
							// Stop at unescaped ws char.
							if (/[ \t]/.test(char) && pchar !== "\\") {
								// argument += char; // Store character.

								let end = argument.length - 1;
								let tN = tNode(vsi, end, argument);
								argument = validate(S, tN, mode);
								args.push([argument, mode]);

								argument = mode = "";
								vsi = 0;
							} else argument += char;
						} else if (mode === "command-flag") {
							// Stop at unescaped ')' char.
							if (char === ")" && pchar !== "\\") {
								argument += char;

								let end = argument.length - 1;
								let tN = tNode(vsi, end, argument);
								argument = validate(S, tN, mode);
								args.push([argument, mode]);

								argument = mode = "";
								vsi = 0;
							} else argument += char;
						}
					}
				}

				// Get last argument.
				if (argument) {
					let tN = tNode(vsi, argument.length - 1, argument);
					argument = validate(S, tN, mode);
					args.push([argument, mode]);
				}

				let cvalues = []; // Build cleaned list.
				args.forEach(item => cvalues.push(item[0]));

				N.args = cvalues;
				N.value.value = value = `(${cvalues.join(" ")})`;
			}

			break;
	}

	return value;
};

module.exports = (...args) => {
	return validate(...args);
};
