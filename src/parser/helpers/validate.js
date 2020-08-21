"use strict";

const error = require("./error.js");
const vtest = require("./vtest.js");
const vcontext = require("./vcontext.js");
const { cin, cnotin, C_SPACES, C_QUOTES } = require("./charsets.js");
const r = /(?<!\\)\$\{\s*[^}]*\s*\}/g;

/**
 * Validates string and interpolates its variables.
 *
 * @param  {object} S - State object.
 * @param  {object} N - Node object.
 * @return {object} - Object containing parsed information.
 */
let validate = (S, N, type) => {
	let { value } = N.value;
	let formatting = S.args.action === "format";
	// Get column index to resume error checks at.
	let resumepoint = N.value.start - S.tables.linestarts[S.line];
	resumepoint++; // Add 1 to account for 0 base indexing.

	// If validating a keyword there must be a value.
	if (N.node === "FLAG" && N.keyword.value) {
		let kw = N.keyword.value;
		let ls = S.tables.linestarts[S.line];
		// Check for misused exclude.
		let sc = S.scopes.command;
		if (sc) {
			if (kw === "exclude" && sc.command.value !== "*") {
				S.column = N.keyword.start - ls;
				S.column++; // Add 1 to account for 0 base indexing.
				error(S, __filename, 17);
			}
		}

		if (!value) {
			S.column = N.keyword.end - ls;
			S.column++; // Add 1 to account for 0 base indexing.
			error(S, __filename, 16);
		}

		let C = kw === "default" ? new Set([...C_QUOTES, "$"]) : C_QUOTES;
		// context, filedir, exclude must have quoted string values.
		if (cnotin(C, value.charAt(0))) {
			S.column = resumepoint;
			error(S, __filename);
		}
	}

	// If value doesn't exist or is '(' (long-form flag list) return.
	if (!value || value === "(") return;

	// Determine type if not provided.
	if (!type) {
		type = "escaped";
		let char = value.charAt(0);
		if (char === "$") type = "command-flag";
		else if (char === "(") type = "list";
		else if (cin(C_QUOTES, char)) type = "quoted";
	}

	/**
	 * Create temporary Node.
	 *
	 * @type {object} - The temp Node object.
	 */
	let tN = { value: { start: 0, end: 0, value: "" } };
	/**
	 * Set temporary Node.value values.
	 *
	 * @param  {number} start - The start index.
	 * @param  {numbers} end - The end index.
	 * @param  {string} val - The value.
	 * @return {undefined} - Nothing is returned.
	 */
	let tNset = (start, end, val) => {
		let { value } = tN;
		value.start = start;
		value.end = end;
		value.value = val;
	};

	switch (type) {
		case "quoted":
			{
				let fchar = value.charAt(~~(value.charAt(0) === "$"));
				let isquoted = cin(C_QUOTES, fchar);
				let l = value.length;
				let lchar = value.charAt(l - 1);
				let schar = value.charAt(l - 2);
				if (isquoted) {
					// Error if improperly quoted/end quote is escaped.
					if (lchar !== fchar || schar === "\\") {
						S.column = resumepoint;
						error(S, __filename, 10);
					}
					// Error it string is empty.
					if (lchar === fchar && l === 2) {
						S.column = resumepoint;
						error(S, __filename, 11);
					}
				}

				// Interpolate variables.
				let vindices = {};
				value = value.replace(r, function (match, index) {
					let lm = match.length - 1;
					match = match.slice(2, -1).trim();

					// Don't interpolate when formatting.
					if (formatting) return `\${${match}}`;

					let value = S.tables.variables[match];
					// Error if var is being used before declared.
					if (!value) {
						S.column = resumepoint + index;
						return error(S, __filename, 12);
					}

					// Calculate variable indices.
					let sl = value.length;
					// let vl = index + sl - index + 1;
					let vl = index + lm - index + 1;
					let dt = sl - vl;
					vindices[index] = [sl > vl ? dt * -1 : Math.abs(dt), sl];
					return value;
				});

				// Validate context string.
				if (
					!formatting &&
					N.node === "FLAG" &&
					N.keyword.value === "context"
				) {
					value = vcontext(S, value, vindices, resumepoint);
				}
				// Validate test string.
				if (
					!formatting &&
					N.node === "SETTING" &&
					N.name.value === "test"
				) {
					value = vtest(S, value, vindices, resumepoint);
				}

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
				if (!value.startsWith("$(")) {
					S.column = resumepoint + 1;
					error(S, __filename, 13);
				}
				// Error if command-flag doesn't end with ')'.
				if (value.charAt(value.length - 1) !== ")") {
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
						if (cin(C_QUOTES, char) && pchar !== "\\") {
							vsi = resume_index;
							qchar = char;
							argument += char;
						} else if (cin(C_SPACES, char)) {
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
						else if (char === "$" && cin(C_QUOTES, nchar)) {
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
							tNset(vsi, argument.length - 1, argument);
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

					tNset(vsi, argument.length - 1, argument);
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
				if (value.charAt(0) !== "(") {
					S.column = resumepoint;
					error(S, __filename, 15);
				}
				// Error if command-flag doesn't end with ')'.
				if (value.charAt(value.length - 1) !== ")") {
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
						if (cin(C_SPACES, char) && pchar !== "\\") continue;

						// Set mode depending on the character.
						if (cin(C_QUOTES, char) && pchar !== "\\") {
							vsi = resume_index;
							mode = "quoted";
							qchar = char;
						} else if (char === "$" && pchar !== "\\") {
							vsi = resume_index;
							mode = "command-flag";
						} else if (cnotin(C_SPACES, char)) {
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
						if (args.length && cnotin(C_SPACES, pchar)) {
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
								tNset(vsi, end, argument);
								argument = validate(S, tN, mode);
								args.push(argument);

								argument = mode = "";
								vsi = 0;
							} else argument += char;
						} else if (mode === "escaped") {
							// Stop at unescaped ws char.
							if (cin(C_SPACES, char) && pchar !== "\\") {
								// argument += char; // Store character.

								let end = argument.length - 1;
								tNset(vsi, end, argument);
								argument = validate(S, tN, mode);
								args.push(argument);

								argument = mode = "";
								vsi = 0;
							} else argument += char;
						} else if (mode === "command-flag") {
							// Stop at unescaped ')' char.
							if (char === ")" && pchar !== "\\") {
								argument += char;

								let end = argument.length - 1;
								tNset(vsi, end, argument);
								argument = validate(S, tN, mode);
								args.push(argument);

								argument = mode = "";
								vsi = 0;
							} else argument += char;
						}
					}
				}

				// Get last argument.
				if (argument) {
					tNset(vsi, argument.length - 1, argument);
					argument = validate(S, tN, mode);
					args.push(argument);
				}

				N.args = args;
				N.value.value = value = `(${args.join(" ")})`;
			}

			break;
	}

	// Remove backslash escapes, but keep escaped backslashes:
	// [https://stackoverflow.com/a/57430306]
	return value.replace(/(?:\\(.))/g, "$1");
};

module.exports = (...args) => validate(...args);
