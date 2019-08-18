"use strict";

// Get needed modules.
let issue = require("./helper.issue.js");

/**
 * Performs checks on string as well as interpolates any variables.
 *
 * @param  {object} STATE - The STATE object.
 * @param  {object} NODE - The NODE object.
 * @return {object} - Object containing parsed information.
 */
module.exports = (STATE, NODE) => {
	// require("./h.trace.js")(__filename); // Trace parser.

	// Get string value.
	let value = NODE.value.value;
	let type = NODE.value.type;

	// If a value does not exist then return.
	if (!value) {
		// Attach empty args array to NODE object.
		NODE.args = [];

		return;
	}

	// Check for long-form flag list. If the value is '(' then it's a
	// long-form flag list.
	if (value === "(") {
		// Add some key-identifying properties to object.
		NODE.openbrace = true;

		// Attach empty args array to NODE object.
		NODE.args = [];

		// Skip remaining logic as it's not needed to execute.
		return;
	}

	// If type was not provided then determine it on the fly.
	if (!type) {
		let fvchar = value.charAt(0); // Get first character from value.
		if (fvchar === "$") {
			type = "command-flag";
		} else if (fvchar === "(") {
			type = "list";
		} else if (/["']/.test(fvchar)) {
			type = "quoted";
		} else {
			type = "escaped";
		}

		// Finally set type.
		NODE.value.type = type;
	}

	// The column index to resume error checks at.
	let resumepoint = NODE.value.start - STATE.DB.linestarts[STATE.line];
	// Note: Add 1 to resumepoint to account for 0 base indexing, as column
	// value starts count at 1.
	resumepoint++;
	let warnings = []; // Collect all parsing warnings.

	switch (type) {
		case "quoted":
			// If a value was extracted make sure it's a valid string. =========

			// Make sure string is properly quoted.
			if (!/^\$?("|').*?\1$/.test(value)) {
				// Reset STATE column index position.
				STATE.column = resumepoint;

				// Note: Closing quote is missing so give error.
				issue.error(STATE, 0, __filename);
			}

			// If string is empty give error.
			if (/^("|')\1$/.test(value)) {
				// Reset STATE column index position.
				STATE.column = resumepoint;

				// Note: String should not be empty.
				issue.error(STATE, 0, __filename);
			}

			// Next, interpolate any variable template-strings. ================

			// Interpolate any template-string variables.
			// [https://stackoverflow.com/a/40329720]
			value = value.replace(/(?<!\\)\$\{\s*[^}]*\s*\}/g, function(
				match,
				index
			) {
				// Remove syntax decorations to get variable name.
				match = match.replace(/^\$\{\s*|\s*\}$/g, "");

				// Note: Skip string interpolation logic if formatting.
				if (STATE.args.formatting) {
					return `\${${match}}`;
				}

				// Lookup variable's value in database.
				let value = STATE.DB.variables[match];

				// Note: If the variable is not in the db then give an error. As
				// a variable cannot be used before declared.
				if (!value) {
					// Reset STATE column index position.
					STATE.column = resumepoint + index;

					return issue.error(STATE, 0, __filename);
				}

				// Else, at this point all is well so return the value.
				return value;
			});

			// Attach args array to NODE object.
			NODE.args = [value];

			// Update value in object.
			NODE.value.value = value;

			break;

		case "escaped":
			// Pass the escaped value for the time begin.being

			// Attach args array to NODE object.
			NODE.args = [value];

			break;
		case "command-flag":
			{
				// Check that command-flag has correct starting/ending syntax. =

				// Note: If command-flag doesn't start with '$(', give error.
				if (!/^\$\(/.test(value)) {
					// Reset STATE column index position.
					STATE.column = resumepoint + 1;

					// Note: String should not be empty.
					issue.error(STATE, 0, __filename);
				}
				// Note: If command-flag doesn't end with ')', give error.
				if (!/\)$/.test(value)) {
					// Reset STATE column index position.
					STATE.column = resumepoint + value.length - 1;

					// Note: String should not be empty.
					issue.error(STATE, 0, __filename);
				}

				// Collect parsed arguments.
				let argument = "";
				let args = [];
				let qchar;
				let delimiter_count = 0;
				let delimiter_index;
				let i = 2; // Offset start index due to syntax '$('.
				// Resume incrementing index for error purposes.
				let resume_index = NODE.value.start + i;
				let value_start_index;

				// Validate that command-flag string is valid.
				// Note: Start loop at index 2 and stop before the last
				// character to ignore the starting '$(' and ending ')'.
				for (let l = value.length - 1; i < l; i++, resume_index++) {
					// Cache current loop item.
					let char = value.charAt(i);
					let pchar = value.charAt(i - 1);
					let nchar = value.charAt(i + 1);

					// qchar is set, grab all chars until an unescaped qchar is hit.
					if (!qchar) {
						// Look for unescaped quote characters.
						if (/["']/.test(char) && pchar !== "\\") {
							// Store the index at which the value starts.
							value_start_index = resume_index;
							// Set qchar as the opening quote character.
							qchar = char;
							// Capture character.
							argument += char;
						} else if (/[ \t]/.test(char)) {
							// Ignore any whitespace outside of quotes.
						} else if (char === ",") {
							// Track number of command delimiters.
							delimiter_count++;
							delimiter_index = i;

							// Note: If delimiter count is more than 1 than
							// there are empty arguments. This is not valid.
							if (delimiter_count > 1 || !args.length) {
								// Reset STATE column index position.
								STATE.column = resumepoint + i;

								// Note: String should not be empty.
								issue.error(STATE, 0, __filename);
							}

							// Look out for '$' prefixed strings.
						} else if (char === "$" && /["']/.test(nchar)) {
							// Set qchar as the opening quote character.
							qchar = nchar;
							// Capture character.
							argument += `${char}${nchar}`;
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

							// Reset STATE column index position.
							STATE.column = resumepoint + i;

							// Note: String should not be empty.
							issue.error(STATE, 0, __filename);
						}
					} else {
						// Capture character.
						argument += char;

						if (char === qchar && pchar !== "\\") {
							// Validate value.
							let tmpNODE = {
								value: {
									start: value_start_index,
									end: argument.length - 1,
									value: argument,
									type: "quoted"
								}
							};
							argument = module.exports(STATE, tmpNODE);

							// Store argument and reset vars.
							args.push(argument);
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
					// Reset STATE column index position.
					STATE.column = resumepoint + delimiter_index;

					// Note: String should not be empty.
					issue.error(STATE, 0, __filename);
				}

				// Get last argument.
				if (argument) {
					// Note: Reduce i to account for last completed iteration.
					i--;

					// Validate value.
					let tmpNODE = {
						value: {
							start: value_start_index,
							end: argument.length - 1,
							value: argument,
							type: "quoted"
						}
					};
					argument = module.exports(STATE, tmpNODE);

					// Store argument and reset vars.
					args.push(argument);
				}

				// Create cleaned command-flag.
				let cvalue = `$(${args.join(",")})`;

				// Attach args array to NODE object.
				NODE.args = [cvalue];

				// Reset value to cleaned arguments command-flag.
				NODE.value.value = value = cvalue;
			}

			break;

		case "list":
			{
				// Check that list has correct starting/ending syntax. =========

				// Note: If command-flag doesn't start with '(', give error.
				if (!/^\(/.test(value)) {
					// Reset STATE column index position.
					STATE.column = resumepoint;

					// Note: String should not be empty.
					issue.error(STATE, 0, __filename);
				}
				// Note: If command-flag doesn't end with ')', give error.
				if (!/\)$/.test(value)) {
					// Reset STATE column index position.
					STATE.column = resumepoint + value.length - 1;

					// Note: String should not be empty.
					issue.error(STATE, 0, __filename);
				}

				// Collect parsed arguments.
				let argument = "";
				let args = [];
				let qchar;
				let delimiter_count = 0;
				let delimiter_index;
				let mode;
				let i = 1; // Offset start index due to syntax '('.
				// Resume incrementing index for error purposes.
				let resume_index = NODE.value.start + i;
				let value_start_index;

				// Validate that command-flag string is valid.
				// Note: Start loop at index 1 and stop before the last
				// character to ignore the starting '(' and ending ')'.
				for (let l = value.length - 1; i < l; i++, resume_index++) {
					// Cache current loop item.
					let char = value.charAt(i);
					let pchar = value.charAt(i - 1);

					if (!mode) {
						// Skip over unescaped whitespace delimiters.
						if (/[ \t]/.test(char) && pchar !== "\\") {
							continue;
						}

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

							// All other characters are invalid so give error.
						} else {
							// Reset STATE column index position.
							STATE.column = resumepoint + i;

							// Note: String should not be empty.
							issue.error(STATE, 0, __filename);
						}

						// Note: If arguments array is already populated
						// and if the previous char is not a space then
						// the argument was not delimited so give an error.
						// Example:
						// subl.command = --flag=(1234 "ca"t"    $("cat"))
						// --------------------------------^ Error point.
						if (args.length && !/[ \t]/.test(pchar)) {
							// Reset STATE column index position.
							STATE.column = resumepoint + i;

							// Note: String should not be empty.
							issue.error(STATE, 0, __filename);
						}

						argument += char; // Store character.
					} else if (mode) {
						if (mode === "quoted") {
							// Stop collecting chars once an unescaped same-style quote is hit.
							if (char === qchar && pchar !== "\\") {
								argument += char; // Store character.
								// Validate value.
								let tmpNODE = {
									value: {
										start: value_start_index,
										end: argument.length - 1,
										value: argument,
										type: mode
									}
								};
								argument = module.exports(STATE, tmpNODE);
								args.push([argument, mode]); // Store argument.
								argument = ""; // Clear argument string.
								mode = null; // Clear mode flag.
								value_start_index = null;
								// Clear mode // Clear start index.
							} else {
								argument += char;
							}
						} else if (mode === "escaped") {
							// Stop collecting once an unescaped whitespace character is hit.
							if (/[ \t]/.test(char) && pchar !== "\\") {
								// argument += char; // Store character.
								// Validate value.
								let tmpNODE = {
									value: {
										start: value_start_index,
										end: argument.length - 1,
										value: argument,
										type: mode
									}
								};
								argument = module.exports(STATE, tmpNODE);
								args.push([argument, mode]); // Store argument.
								argument = ""; // Clear argument string.
								mode = null; // Clear mode flag.
								value_start_index = null; // Clear start index.
							} else {
								argument += char;
							}
						} else if (mode === "command-flag") {
							// Stop collecting when an unescaped ')' character is hit.
							if (char === ")" && pchar !== "\\") {
								argument += char; // Store character.
								// Validate value.
								let tmpNODE = {
									value: {
										start: value_start_index,
										end: argument.length - 1,
										value: argument,
										type: mode
									}
								};

								argument = module.exports(STATE, tmpNODE);
								args.push([argument, mode]); // Store argument.
								argument = ""; // Clear argument string.
								mode = null; // Clear mode flag.
								value_start_index = null; // Clear start index.
							} else {
								argument += char;
							}
						}
					}
				}

				// // Note: If delimiter_index flag is still set then we have a
				// // trailing comma delimiter so give an error.
				// if (delimiter_index) {
				// 	// Reset STATE column index position.
				// 	STATE.column = resumepoint + delimiter_index;

				// 	// Note: String should not be empty.
				// 	issue.error(STATE, 0, __filename);
				// }

				// Get last argument.
				if (argument) {
					// Validate value.
					let tmpNODE = {
						value: {
							start: value_start_index,
							end: argument.length - 1,
							value: argument,
							type: mode
						}
					};
					argument = module.exports(STATE, tmpNODE);
					args.push([argument, mode]);
				}

				// Build cleaned list string.
				let cvalues = [];
				args.forEach(item => {
					cvalues.push(item[0]);
				});

				// Attach args array to NODE object.
				NODE.args = cvalues;

				// Reset value to cleaned arguments command-flag.
				NODE.value.value = value = `(${cvalues.join(" ")})`;
			}

			break;
	}

	return value;
};
