"use strict";

const error = require("./error.js");

/**
 * Performs checks on string as well as interpolates any variables.
 *
 * @param  {object} S - Main loop state object.
 * @param  {object} N - The node object.
 * @return {object} - Object containing parsed information.
 */
module.exports = (S, N, type) => {
	let { value } = N.value;

	// Start: Short Circuit Checks. ============================================

	// Note: If a value does not exist then return.
	if (!value) {
		N.args = []; // Attach empty args array to N object.

		return; // Exit early.
	}

	// Note: If value is '(' then it's a long-form flag list.
	if (value === "(") {
		N.openbrace = true; // Add some key-identifying properties to object.
		N.args = []; // Attach empty args array to N object.

		return; // Exit early.
	}

	// End: Short Circuit Checks ===============================================

	// Determine type if not provided.
	if (!type) {
		type = "escaped"; // Default value.
		let fvchar = value.charAt(0); // Value's first character.

		if (fvchar === "$") type = "command-flag";
		else if (fvchar === "(") type = "list";
		else if (/["']/.test(fvchar)) type = "quoted";
	}

	// The column index to resume error checks at.
	let resumepoint = N.value.start - S.tables.linestarts[S.line];
	// Note: Add 1 to resumepoint to account for 0 base indexing,
	resumepoint++; // as column value starts count at 1.

	switch (type) {
		case "quoted":
			{
				// If a value was extracted make sure it's a valid string. ====

				// Make sure string is properly quoted.
				if (!/^\$?("|').*?\1$/.test(value)) {
					S.column = resumepoint; // Reset index position.

					error(S, __filename, 10); // Note: Close quote is missing so error.
				}

				// If string is empty give error.
				if (/^("|')\1$/.test(value)) {
					S.column = resumepoint; // Reset index position.

					error(S, __filename, 11); // Note: String shouldn't be empty.
				}

				// Next, interpolate any variable template-strings. ============

				// Interpolate any template-string variables.
				// [https://stackoverflow.com/a/40329720]
				const r = /(?<!\\)\$\{\s*[^}]*\s*\}/g;
				value = value.replace(r, function(match, index) {
					// Remove syntax decorations to get variable name.
					match = match.replace(/^\$\{\s*|\s*\}$/g, "");

					// Note: Skip string interpolation logic if formatting.
					if (S.args.fmt) return `\${${match}}`;

					// Lookup variable's value in database.
					let value = S.tables.variables[match];

					// Note: If the variable is not in the db then give an error.
					// as a variable cannot be used before declared.
					if (!value) {
						S.column = resumepoint + index; // Reset index position.

						// Note: Variable does not exist in lookup.
						return error(S, __filename, 12);
					}

					return value;
				});

				N.args = [value]; // Attach args array to N object.
				N.value.value = value; // Update value in object.
			}

			break;

		case "escaped":
			// Attach args array to N object.
			N.args = [value];

			break;
		case "command-flag":
			{
				// Check command-flag has correct starting/ending syntax.

				// Note: If command-flag doesn't start with '$(', give error.
				if (!/^\$\(/.test(value)) {
					S.column = resumepoint + 1; // Reset index position.

					error(S, __filename, 13); // Note: String shouldn't be empty.
				}
				// Note: If command-flag doesn't end with ')', give error.
				if (!/\)$/.test(value)) {
					// Reset index position.
					S.column = resumepoint + value.length - 1;

					error(S, __filename, 13); // Note: String shouldn't be empty.
				}

				// Collect parsed arguments.
				let argument = "";
				let args = [];
				let qchar;
				let delimiter_count = 0;
				let delimiter_index;
				let i = 2; // Offset start index due to syntax '$('.
				// Resume incrementing index for error purposes.
				let resume_index = N.value.start + i;
				let value_start_index;

				// Validate that command-flag string is valid.
				// Note: Start loop at index 2 and stop before the last
				// character to ignore the starting '$(' and ending ')'.
				for (let l = value.length - 1; i < l; i++, resume_index++) {
					let char = value.charAt(i);
					let pchar = value.charAt(i - 1);
					let nchar = value.charAt(i + 1);

					// qchar is set, grab all chars until an unescaped qchar is hit.
					if (!qchar) {
						// Look for unescaped quote characters.
						if (/["']/.test(char) && pchar !== "\\") {
							// Store the index at which the value starts.
							value_start_index = resume_index;
							qchar = char; // Store qchar.
							argument += char; // Capture character.
						} else if (/[ \t]/.test(char)) {
							// Ignore any whitespace outside of quotes.
						} else if (char === ",") {
							// Track number of command delimiters.
							delimiter_count++;
							delimiter_index = i;

							// Note: If delimiter count is more than 1 than
							// there are empty arguments. This is not valid.
							if (delimiter_count > 1 || !args.length) {
								// Reset index position.
								S.column = resumepoint + i;

								// Note: String shouldn't be empty.
								error(S, __filename, 14);
							}

							// Look out for '$' prefixed strings.
						} else if (char === "$" && /["']/.test(nchar)) {
							qchar = nchar; // Stpre qchar.
							argument += `${char}${nchar}`; // Capture character.
							resume_index++;
							i++;
							value_start_index = resume_index;
						} else {
							// Give error as anything else is not allowed. For
							// example, hitting this block means a character
							// is not being quoted. Something like this can
							// trigger this block.
							// $("arg1", "arg2", arg3 )
							// ------------------^ Value is unquoted.

							// Reset index position.
							S.column = resumepoint + i;

							// Note: String shouldn't be empty.
							error(S, __filename);
						}
					} else {
						argument += char; // Capture character.

						if (char === qchar && pchar !== "\\") {
							// Validate value.
							let tmpN = {
								value: {
									start: value_start_index,
									end: argument.length - 1,
									value: argument
								}
							};
							argument = module.exports(S, tmpN, "quoted");

							args.push(argument); // Store argument.
							// Clear/reset variables.
							argument = "";
							qchar = "";
							delimiter_index = null;
							delimiter_count = 0;
						}
					}
				}

				// Note: If delimiter_index flag is still set then we have a
				// trailing comma delimiter so give an error.
				if (delimiter_index && !argument) {
					// Reset index position.
					S.column = resumepoint + delimiter_index;

					error(S, __filename, 14); // Note: String shouldn't be empty.
				}

				// Get last argument.
				if (argument) {
					i--; // Reduce to account for last completed iteration.

					// Validate value.
					let tmpN = {
						value: {
							start: value_start_index,
							end: argument.length - 1,
							value: argument
						}
					};
					argument = module.exports(S, tmpN, "quoted");

					args.push(argument); // Store argument.
				}

				// Create cleaned command-flag.
				let cvalue = `$(${args.join(",")})`;
				N.args = [cvalue]; // Attach args array to N object.
				// Reset value to cleaned arguments command-flag.
				N.value.value = value = cvalue;
			}

			break;

		case "list":
			{
				// Check list has correct starting/ending syntax. =========

				// Note: If list doesn't start with '(', give error.
				if (!/^\(/.test(value)) {
					S.column = resumepoint; // Reset index position.

					error(S, __filename, 15); // Note: String shouldn't be empty.
				}
				// Note: If command-flag doesn't end with ')', give error.
				if (!/\)$/.test(value)) {
					// Reset index position.
					S.column = resumepoint + value.length - 1;

					error(S, __filename, 15); // Note: String shouldn't be empty.
				}

				// Collect parsed arguments.
				let argument = "";
				let args = [];
				let qchar;
				let mode;
				let i = 1; // Offset start index due to syntax '('.
				// Resume incrementing index for error purposes.
				let resume_index = N.value.start + i;
				let value_start_index;

				// Validate that command-flag string is valid.
				// Note: Start loop at index 1 and stop before the last
				// character to ignore the starting '(' and ending ')'.
				for (let l = value.length - 1; i < l; i++, resume_index++) {
					let char = value.charAt(i);
					let pchar = value.charAt(i - 1);

					if (!mode) {
						// Skip over unescaped whitespace delimiters.
						if (/[ \t]/.test(char) && pchar !== "\\") continue;

						// Set mode depending on the character.
						if (/["']/.test(char) && pchar !== "\\") {
							// Store the index at which the value starts.
							value_start_index = resume_index;
							mode = "quoted"; // Set mode.
							qchar = char; // Store quote char for later reference.
						} else if (char === "$" && pchar !== "\\") {
							// Store the index at which the value starts.
							value_start_index = resume_index;
							mode = "command-flag"; // Set mode.
						} else if (!/[ \t]/.test(char)) {
							// Store the index at which the value starts.
							value_start_index = resume_index;
							mode = "escaped"; // Set mode.
						}
						// All other characters are invalid so give error.
						else {
							// Reset index position.
							S.column = resumepoint + i;

							// Note: String shouldn't be empty.
							error(S, __filename);
						}

						// Note: If arguments array is already populated
						// and if the previous char is not a space then
						// the argument was not delimited so give an error.
						// Example:
						// subl.command = --flag=(1234 "ca"t"    $("cat"))
						// --------------------------------^ Error point.
						if (args.length && !/[ \t]/.test(pchar)) {
							// Reset index position.
							S.column = resumepoint + i;

							// Note: String shouldn't be empty.
							error(S, __filename);
						}

						argument += char; // Store character.
					} else if (mode) {
						if (mode === "quoted") {
							// Stop collecting chars once an unescaped same-style quote is hit.
							if (char === qchar && pchar !== "\\") {
								argument += char; // Store character.
								// Validate value.
								let tmpN = {
									value: {
										start: value_start_index,
										end: argument.length - 1,
										value: argument
									}
								};
								argument = module.exports(S, tmpN, mode);
								args.push([argument, mode]); // Store argument.
								argument = ""; // Clear argument string.
								mode = null; // Clear mode flag.
								value_start_index = null; // Clear start index.
							} else argument += char;
						} else if (mode === "escaped") {
							// Stop collecting once an unescaped whitespace character is hit.
							if (/[ \t]/.test(char) && pchar !== "\\") {
								// argument += char; // Store character.
								// Validate value.
								let tmpN = {
									value: {
										start: value_start_index,
										end: argument.length - 1,
										value: argument
									}
								};
								argument = module.exports(S, tmpN, mode);
								args.push([argument, mode]); // Store argument.
								argument = ""; // Clear argument string.
								mode = null; // Clear mode flag.
								value_start_index = null; // Clear start index.
							} else argument += char;
						} else if (mode === "command-flag") {
							// Stop collecting when an unescaped ')' character is hit.
							if (char === ")" && pchar !== "\\") {
								argument += char; // Store character.
								// Validate value.
								let tmpN = {
									value: {
										start: value_start_index,
										end: argument.length - 1,
										value: argument
									}
								};

								argument = module.exports(S, tmpN, mode);
								args.push([argument, mode]); // Store argument.
								argument = ""; // Clear argument string.
								mode = null; // Clear mode flag.
								value_start_index = null; // Clear start index.
							} else argument += char;
						}
					}
				}

				// Get last argument.
				if (argument) {
					// Validate value.
					let tmpN = {
						value: {
							start: value_start_index,
							end: argument.length - 1,
							value: argument
						}
					};
					argument = module.exports(S, tmpN, mode);
					args.push([argument, mode]);
				}

				// Build cleaned list string.
				let cvalues = [];
				args.forEach(item => cvalues.push(item[0]));

				// Attach args array to N object.
				N.args = cvalues;
				// Reset value to cleaned arguments command-flag.
				N.value.value = value = `(${cvalues.join(" ")})`;
			}

			break;
	}

	return value;
};
