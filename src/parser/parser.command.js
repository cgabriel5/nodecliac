"use strict";

// Get needed modules.
let issue = require("./helper.issue.js");
// const pflagset = require("./p.flagset.js");
// Get RegExp patterns.
let { r_nl, r_whitespace } = require("./h.patterns.js");

/**
 * Parses command chain line to extract command chain.
 *
 * ---------- Parsing States Breakdown -----------------------------------------
 * program.command = [ ]?
 * program.command = [
 * program.command = --flag
 * program.command =
 * program.command ,
 * program.command
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
 * @param  {string} string - The line to parse.
 * @return {object} - Object containing parsed information.
 */
module.exports = STATE => {
	// require("./h.trace.js")(__filename); // Trace parser.

	// Get global loop state variables.
	let { line, l, string } = STATE;

	// Parsing vars.
	let state = "command"; // Initial parsing state.
	let qchar;
	let warnings = []; // Collect all parsing warnings.
	let DATA = {
		node: "COMMAND",
		sigil: { start: null, end: null },
		command: { start: null, end: null, value: "" },
		name: { start: null, end: null, value: "" },
		brackets: { start: null, end: null },
		assignment: { start: null, end: null, value: null },
		delimiter: { start: null, end: null, value: null },
		value: { start: null, end: null, value: null },
		// wsb: { start: null, end: null },
		line,
		startpoint: STATE.i,
		endpoint: null // Then index at which parsing was ended.
	};

	// Loop over string.
	for (; STATE.i < l; STATE.i++) {
		let char = string.charAt(STATE.i); // Cache current loop item.

		// End loop on a new line char.
		if (r_nl.test(char)) {
			// Note: When setting the endpoint make sure to subtract index
			// by 1 so that when it returns to its previous loop is can run
			// the newline character code block.
			DATA.endpoint = STATE.i - 1; // Store newline index.
			STATE.i = STATE.i - 1; // Store newline index.
			break;
		}

		STATE.column++; // Increment column position.

		console.log(2222222222222, char, state);

		// Default parse state.

		switch (state) {
			case "command":
				// If command value is empty check for first letter of command.
				if (!DATA.command.value) {
					// First char of command must be a letter or semicolon.
					if (!/[:a-zA-Z]/.test(char)) {
						// [TODO]: Specify Error: Setting must start with a letter.
						issue.error(STATE, 0, __filename);
					}

					// Set command index positions.
					DATA.command.start = STATE.i;
					DATA.command.end = STATE.i;

					// Start building setting command string.
					DATA.command.value += char;

					// Continue building setting command string.
				} else {
					// If char is allowed keep building string.
					if (/[-_.:+\\/a-zA-Z0-9]/.test(char)) {
						// Set command index positions.
						DATA.command.end = STATE.i;
						// Continue building setting command string.
						DATA.command.value += char;

						// When escaping anything but a dot do not include
						// the '\' as it is not needed. For example, if the
						// command is 'com\mand\.name' we should return
						// 'command\.name' and not 'com\mand\.name'.
						if (char === "\\") {
							// Get the next char.
							let nchar = string.charAt(STATE.i + 1);

							// Note: If the next char does not exist then the
							// '\' is escaping nothing so error.
							if (!nchar) {
								issue.error(STATE, 0, __filename);
							}

							// Next char must be a space for it to be a valid
							// escape sequence.
							if (nchar !== ".") {
								// Note: Escaping anything but a dot give is
								// not allowed, so give error.
								// issue.warning(STATE, 0, __filename);
								issue.error(STATE, 0, __filename);

								// Remove last escape char as it is not needed.
								let command = DATA.command.value.slice(0, -1);
								DATA.command.value = command;
							}
						}

						// If we encounter a whitespace character, everything
						// after this point must be a space until we encounter
						// an eq sign or the end-of-line (newline) character.
					} else if (/[ \t]/.test(char)) {
						state = "chain-wsb";
						continue;

						// If char is an eq sign change state/reset index.
					} else if (char === "=") {
						state = "assignment";

						// Note: Rollback index by 1 to allow parser to
						// start at assignment case on next iteration.
						STATE.i -= 1;
						STATE.column--;

						// Anything else the character is not allowed.
					} else if (char === ",") {
						state = "delimiter";

						// Note: Rollback index by 1 to allow parser to
						// start at delimiter case on next iteration.
						STATE.i -= 1;
						STATE.column--;

						// Anything else the character is not allowed.
					} else {
						// Note: Hitting this block means an invalid
						// character was encountered so give an error.
						issue.error(STATE, 0, __filename);
					}
				}

				break;

			case "chain-wsb":
				// At this point we are looking for the assignment operator
				// or a delimiter. Anything but whitespace, eq-sign, or command
				// are invalid chars.
				if (!/[ \t]/.test(char)) {
					if (char === "=") {
						// Change sate to assignment.
						state = "assignment";

						// Note: Rollback index by 1 to allow parser to
						// start at assignment case on next iteration.
						STATE.i -= 1;
						STATE.column--;
					} else if (char === ",") {
						// Change sate to delimiter.
						state = "delimiter";

						// Note: Rollback index by 1 to allow parser to
						// start at assignment case on next iteration.
						STATE.i -= 1;
						STATE.column--;
					} else {
						// Note: Hitting this block means an invalid
						// character was encountered so give an error.
						issue.error(STATE, 0, __filename);
					}
				}

				break;

			case "assignment":
				// Store index positions.
				DATA.assignment.start = STATE.i;
				DATA.assignment.end = STATE.i;
				// Store assignment character.
				DATA.assignment.value = char;

				// Change state to look for any space post assignment but
				// before the actual setting's value.
				state = "value-wsb";

				break;

			case "delimiter":
				// Store index positions.
				DATA.delimiter.start = STATE.i;
				DATA.delimiter.end = STATE.i;
				// Store assignment character.
				DATA.delimiter.value = char;

				// Only whitespace is allowed after a chain delimiter so set
				// state to end-of-line whitespace boundary.
				state = "eol-wsb";

				break;

			case "value-wsb":
				// Ignore consecutive whitespace. Once a non-whitespace
				// character is hit, switch to value state.
				if (!/[ \t]/.test(char)) {
					state = "value";

					// Note: Rollback index by 1 to allow parser to
					// start at assignment case on next iteration.
					STATE.i -= 1;
					STATE.column--;
				}

				break;

			case "value":
				// Note: This will be an intermediary step. May be removed?
				// Determine value type. If character is '[' then start
				// open-bracket case. Else if character is '-' then
				// commence 'oneliner' route.

				// Before determining path, check that character is valid.
				if (!/[-\[]/.test(char)) {
					issue.error(STATE, 0, __filename);
				}

				state = char === "[" ? "open-bracket" : "oneliner";

				// Note: Rollback index by 1 to allow parser to
				// start at assignment case on next iteration.
				STATE.i -= 1;
				STATE.column--;

				break;

			case "open-bracket":
				// Note: This will be an intermediary step. May be removed?

				// Store index positions.
				DATA.brackets.start = STATE.i;

				// Allow for any number of white spaces after open-bracket.
				state = "open-bracket-wsb";

				break;

			case "open-bracket-wsb":
				// Ignore consecutive whitespace. Once a non-whitespace
				// character is hit, switch to value state.
				if (!/[ \t]/.test(char)) {
					state = "close-bracket";

					// Note: Rollback index by 1 to allow parser to
					// start at assignment case on next iteration.
					STATE.i -= 1;
					STATE.column--;
				}

				break;

			case "close-bracket":
				// At this point the char must be a closing bracket ']'.
				// Anything else is invalid.
				if (char !== "]") {
					issue.error(STATE, 0, __filename);
				}

				// Store index positions.
				DATA.brackets.end = STATE.i;

				// Only whitespace is allowed now so set state to
				// end-of-line whitespace boundary.
				state = "eol-wsb";

				break;

			case "oneliner":
				// Note: Reduce column counter by 1 since parser loop will
				// commence at the start of the first non whitespace char.
				// A char that has already been looped over in the main loop.
				STATE.column--;

				// Store result in variable to access the
				// interpolated variable's value.
				// let res = p_oneliner(STATE); // Run flag oneliner parser...

				// // Add interpolated value to string.
				// DATA.value.value += res.variable.value;

				// // With RegExp to parse on unescaped '|' characters it would be
				// // something like this: String.split(/(?<=[^\\]|^|$)\|/);
				// // [https://stackoverflow.com/a/25895905]
				// // [https://stackoverflow.com/a/12281034]

				// // Get individual flag sets. Use unescaped '|' as the delimiter.
				// if (char === "|" && pchar !== "\\") {
				// 	// Run flag value parser from here...
				// 	let pvalue = pflagset();
				// }

				break;

			case "eol-wsb":
				if (!/[ \t]/.test(char)) {
					// Note: At this point all states have been gone through.
					// All that should remain, if anything, are trailing
					// whitespace Anything other than trailing whitespace is
					// invalid.
					issue.error(STATE, 0, __filename);
				}

				break;
		}
	}

	console.log(DATA);
	console.log();
	console.log();
	return DATA;

	// // If brace index is set it was never closed.
	// if (indices.shortcut.open) {
	// 	// Reset index opened shortcut brace.
	// 	i = indices.shortcut.open;
	// 	return issue("error", 7, "{");
	// }

	// // Add the last command.
	// if (command) {
	// 	commands.push(command);
	// }

	// // Join command parts and reset chain to normalized chain string.
	// chain = commands.join("");

	// // Store chain as a global.
	// setchain(chain);

	// // [TODO] Use a function to not repeat followed pflagset logic.

	// // Add final flag set.
	// if (flagset) {
	// 	// Run flag value parser from here...
	// 	let pvalue = pflagset({
	// 		str: [indices.oneliner.start], // Index to resume parsing at.
	// 		usepipe: true // End parsing either on newlines or pipe chars.
	// 	});

	// 	// Join warnings.
	// 	if (pvalue.warnings.length) {
	// 		warnings = warnings.concat(pvalue.warnings);
	// 	}
	// 	// If error exists return error.
	// 	if (pvalue.code) {
	// 		return pvalue;
	// 	}

	// 	// Get result values.
	// 	let symbol = pvalue.symbol;
	// 	let keyword = pvalue.keyword;
	// 	let name = pvalue.name;
	// 	let hname = pvalue.h.name;
	// 	let assignment = pvalue.assignment;
	// 	let value = pvalue.args;
	// 	let hvalue = pvalue.h.hargs;
	// 	let nl_index = pvalue.nl_index;

	// 	// For keyword declarations.
	// 	if (keyword) {
	// 		// Get highlighted/non-highlighted keywords.
	// 		let [, hkeyword] = keyword;
	// 		keyword = keyword[0];

	// 		// Store the provided command string fallback (default/always).
	// 		store_fallback(keyword, hkeyword, value, hvalue, chain);

	// 		// Reset flag to newly parsed value.
	// 		flagset = `${keyword} ${value}`;
	// 		// Set highlighted version.
	// 		hflagset = `${hkeyword} ${hvalue}`;
	// 	} else {
	// 		// If value is not a string (therefore an array) join values.
	// 		if (typeof value !== "string" && value.length > 1) {
	// 			value = `(${value.join(" ")})`;
	// 			hvalue = `(${hvalue.join(" ")})`;
	// 		}

	// 		// Reset flag to newly parsed value.
	// 		flagset = `${symbol}${name}${assignment}${value}`;
	// 		// Set highlighted version.
	// 		hflagset = `${symbol}${hname}${assignment}${hvalue}`;
	// 	}

	// 	// Reset oneliner start index.
	// 	indices.oneliner.start = (nl_index || i) + 1;

	// 	// Don't add fallback (default/always) to flagsets as they have
	// 	// their own section (bottom of output) unless formatting.
	// 	if (!keyword || formatting) {
	// 		// Store current flag set.
	// 		flagsets.push(flagset);
	// 		// Set highlighted version.
	// 		hflagsets.push(hflagset);
	// 	}

	// 	// Reset flag set string.
	// 	flagset = "";
	// 	hflagset = "";
	// }

	// // If there was assignment do some value checks.
	// if (assignment && !flagsets.length) {
	// 	// Determine brace state.
	// 	brstate =
	// 		value === "[]" ? "closed" : value === "[" ? "open" : undefined;

	// 	// If assignment but not value give warning.
	// 	if (!value) {
	// 		// Reset index to point to eq sign.
	// 		i = indices.assignment.index;

	// 		// Add warning.
	// 		issue("warning", 5, "=");
	// 	}

	// 	// If assignment but not value give warning.
	// 	if (brstate === "closed") {
	// 		// Reset index to point to opening brace'['.
	// 		i = indices.value.start;

	// 		// Add warning.
	// 		issue("warning", 6);
	// 	}
	// }

	// // Check if command chain is a duplicate.
	// if (lookup[chain]) {
	// 	// Reset index.
	// 	i = indices.chain.end;

	// 	// Add warning.
	// 	issue("warning", 10, chain);
	// }

	// // Unset global oneliner flag set used for dupe checks.
	// if (global.$app.vars.oneliner) {
	// 	delete global.$app.vars.oneliner;
	// 	global.$app.size(-1); // Decrease size by 1.
	// }

	// // Return relevant parsing information.
	// return {
	// 	chain,
	// 	value,
	// 	brstate,
	// 	assignment,
	// 	flagsets,
	// 	hflagsets,
	// 	nl_index,
	// 	delimiter,
	// 	warnings,
	// 	has_shortcuts,
	// 	is_oneliner,
	// 	// Return brace opening index for later error checks.
	// 	br_open_index: indices.braces.open - line_fchar + 1, // Add 1 to account for 0 index.
	// 	// Return delimiter index for later error checks.
	// 	delimiter_index: indices.delimiter.index - line_fchar + 1,
	// 	h: {
	// 		chain: h(chain, "command")
	// 	}
	// };
};
