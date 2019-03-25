"use strict";

// Parser:
// ✓ comments
// 	✓ single line
// 	✖ trailing-ending comments
// ✓ @settings
// ✓ command chains
// 	✓ shortcuts
// ✓ long-form flags
// 	✓ command-flags
// 	✓ flags options list

// ✖ balanced braces - necessary?
// ✖ validate characters for command chains
// ✖ account for line numbers/errors

// Needed modules.
// const path = require("path");
const chalk = require("chalk");
const { exit } = require("../utils.js");

// Require parser functions.
const merge = require("./merge.js");
const config = require("./config.js");
const dedupe = require("./dedupe.js");
const argparser = require("./argparser.js");
const lookahead = require("./lookahead.js");
const shortcuts = require("./shortcuts.js");
const paramparse = require("./paramparse.js");
const formatflags = require("./formatflags.js");
// Get parsers.
const psetting = require("./p.setting.js");
const pcommand = require("./p.command.js");
const pbrace = require("./p.close-brace.js");
const pflagset = require("./p.flagset.js");
const pflagoption = require("./p.flagoption.js");
// Error checking functions.
const {
	issue,
	error,
	// Rename functions to later wrap.
	verify: everify,
	brace_check: ebc
} = require("./error.js");

module.exports = (contents, commandname, source) => {
	// Vars - Line information.
	let line = "";
	let line_num = 1;
	let line_fchar;
	let indentation = "";

	// Vars - General.
	let lookup = {};
	let settings = {};
	let newlines = [];
	let warnings = [];

	// Vars - Parser flags.
	let line_type; // Store current type of line being parsed.
	let currentflag; // Store flag name of currently parsed flag list.
	let currentchain; // Store current command chain.

	// Vars - Tracking.
	let last_open_br; // Track open/closing brackets.
	let last_open_pr; // Track open/closing parentheses.
	let flag_count; // Track command's flag count.
	let flag_count_options; // Track flag's option count.

	// RegExp patterns:
	let r_letter = /[a-zA-Z]/; // Letter.
	let r_whitespace = /[ \t]/; // Whitespace.
	let r_nl = new RegExp(`(\\r?\\n)`); // New line character.
	let r_start_line_char = /[-@a-zA-Z\)\]#]/; // Starting line character.

	// Wrap needed error functions to add fixed parameters.
	let verify = result => {
		return everify(result, warnings);
	};
	let brace_check = (issue, brace_style) => {
		return ebc({
			issue,
			brace_style,
			last_open_br,
			last_open_pr,
			indentation,
			warnings
		});
	};

	// ACMAP file header.
	let header = [
		`# THIS FILE IS AUTOGENERATED —— DO NOT EDIT FILE DIRECTLY.`,
		`# ${new Date()};${Date.now()}`,
		`# nodecliac definition mapfiles: ~/.nodecliac/defs/\n`
	];

	// Main loop. Loops over each character in acmap.
	for (let i = 0, l = contents.length; i < l; i++) {
		// Cache current/previous/next chars.
		let char = contents.charAt(i);
		let pchar = contents.charAt(i - 1);
		let nchar = contents.charAt(i + 1);

		// Check if \r?\n newline sequence.
		if ((char === "\r" && nchar === "\n") || char === "\n") {
			// Increment line counter.
			line_num++;
			// Reset line char index.
			line_fchar = null;

			// The line type will get switched to "command_setter" after
			// extracting the command chain. However, when the command chain
			// does not contain a setter and therefore also no flags the
			// command chain needs to be cleared to catch any flags not
			// contained within [].
			if (line_type === "command_setter") {
				currentchain = "";
			}

			// Reset vars.
			line = "";
			line_type = null;
			indentation = "";

			continue;
		}

		// Store index of first character in current line.
		if (!line_fchar) {
			line_fchar = i;
		}

		// If a line type has not been defined yet.
		if (!line_type) {
			// If the current character is a space then continue.
			if (r_whitespace.test(char)) {
				indentation += char;
				continue;
			}

			// If not a space character, look for an allowed character.
			// Lines can start with following chars/char sets.
			// @      → setting
			// #      → comment
			// a-zA-Z → command chain
			//     -      → flag
			//     '- '   → flag option (ignore quotes)
			//     )      → closing flag set
			//     ]      → closing long-flag form
			// -------------------------------------------------------------
			// Special flag characters to look out for:
			// $(, "", ''

			// If current flag is set only comments, flag options, and
			// closing parenthesis are allowed.
			if (currentflag) {
				line_type = "flag_option";
				if (char === ")") {
					line_type = "close_parenthesis";
				} else if (char === "#") {
					line_type = "comment";
				}
			} else {
				// Char must be an allowed starting char.
				if (!r_start_line_char.test(char)) {
					error(char, 0, line_num, indentation.length);
				}

				// Set line start type.
				if (char === "@") {
					line_type = "setting";
				} else if (char === "#") {
					line_type = "comment";
				} else if (r_letter.test(char)) {
					line_type = "command";

					// If a current chain flag is set then another chain
					// cannot be parsed. This means the chain is nested.
					if (currentchain) {
						error("", 1, line_num, 0);
					}
				} else if (char === "]") {
					line_type = "close_bracket";
				} else if (char === "-") {
					// If flag is set we are getting flag options.
					line_type = currentflag
						? // Option must my listed with a hyphen.
						  // /\s/.test(nchar)
						  "flag_option"
						: "flag_set";

					// If command chain does not exist but a flag_set/option
					// was detected there is an unnested/unwrapped flag/option.
					if (!currentchain) {
						// Look ahead to grab setting line.
						let { indices, chars_str } = lookahead(
							i,
							contents,
							r_nl
						);

						// Improperly nested flag option.
						if (/^-[ \t]/.test(chars_str)) {
							error("", 3, line_num, 0);
						}
						// Flag is improperly nested.
						else if (/^-{1,2}/) {
							error("", 4, line_num, 0);
						}

						// General error.
						error("", 5, line_num, 0);
					}
				} else if (char === ")") {
					line_type = "close_parenthesis";
				}

				// Following commands cannot begin with any whitespace.
				if (
					indentation.length &&
					["setting", "command"].includes(line_type)
				) {
					// Line cannot begin begin with whitespace.
					error("", 6, line_num, 0);
				}
			}
			// line += char;
		}

		if (line_type) {
			if (line_type === "setting") {
				// Parse line.
				let result = psetting(
					contents,
					i,
					l,
					line_num,
					line_fchar,
					settings
				);

				// Check result for parsing issues (errors/warnings).
				verify(result);

				// When parsing passes reset the index so that on the next
				// iteration it continues with the newline character.
				i = result.nl_index - 1;

				// Store setting/value pair.
				settings[result.name] = result.value;
			} else if (line_type === "command") {
				// Check for an unclosed '['.
				brace_check("unclosed", "[");

				// Parse line.
				let result = pcommand(contents, i, l, line_num, line_fchar);

				// Check result for parsing issues (errors/warnings).
				verify(result);

				// When parsing passes reset the index so that on the next
				// iteration it continues with the newline character.
				i = result.nl_index - 1;

				// Get command chain.
				let cc = result.chain;
				let value = result.value;
				// Get opening brace index.
				let br_index = result.br_open_index;

				// Store command chain.
				if (!lookup[cc]) {
					lookup[cc] = [];
				}
				// Store current command chain.
				currentchain = cc;

				// For non flag set one-liners.
				if (result.brstate) {
					// If brackets are empty set flags.
					if (result.brstate === "closed") {
						// Reset flags.
						currentchain = "";
						last_open_br = null;
					}
					// If bracket is unclosed set other flags.
					else {
						// Set flag set counter.
						flag_count = [line_num, 0];
						// Store line + opening bracket index.
						last_open_br = [line_num, br_index];
					}
				} else {
					// Clear values.
					currentchain = "";

					// Store flagsets with its command chain in lookup table.
					let chain = lookup[result.chain];
					if (chain) {
						// Get flag sets.
						let flags = result.flagsets;

						// Add each flag set to its command chain.
						for (let j = 0, ll = flags.length; j < ll; j++) {
							// Cache current loop item.
							let flag = flags[j].trim();

							// Skip empty flags.
							if (!/^-{1,}$/.test(flag)) {
								chain.push(flag);
							}
						}
					}
				}
			} else if (line_type === "flag_set") {
				// Check for an unclosed '('.
				brace_check("unclosed", "(");

				// Parse line.
				let result = pflagset(
					contents,
					i,
					l,
					line_num,
					line_fchar,
					indentation
				);

				// Check result for parsing issues (errors/warnings).
				verify(result);

				// // Must pass RegExp pattern.
				// if (!r_flag_set.test(chars_str)) {
				// 	// Check if it's a flag option. If so the option is not
				// 	// being assigned to a flag.
				// 	if (r_flag_option.test(chars_str)) {
				// 		error(`Unassigned flag option.`);
				// 	}
				// 	// General error.
				// 	error(`Invalid flag.`);
				// }

				// Breakdown flag.
				let hyphens = result.symbol;
				let flag = result.name;
				let setter = result.assignment;
				let values = result.value;
				let special = result.special;
				let isopeningpr = result.isopeningpr;
				// Get opening brace index.
				let pr_index = result.pr_open_index;

				// If we have a flag like '--flag=(' we have a long-form
				// flag list opening. Store line for later use in case
				// the parentheses is not closed.
				if (isopeningpr) {
					// Store line + opening parentheses index for use in error
					// later if needed.
					last_open_pr = [line_num, pr_index];
					currentflag = `${hyphens}${flag}`;
				}

				// Add to lookup table if not already.
				let chain = lookup[currentchain];
				if (chain) {
					// Add flag itself to lookup table > command chain.
					chain.push(`${hyphens}${flag}${setter}`);

					// It not an opening brace then add values.
					if (!isopeningpr) {
						// Loop over values and add to lookup table.
						for (let i = 0, l = values.length; i < l; i++) {
							// Cache current loop item.
							let value = values[i];

							// Add to lookup table > command chain.
							chain.push(`${hyphens}${flag}${setter}${value}`);
						}
					}
				}

				// Increment flag set counter.
				if (flag_count) {
					// Get values before incrementing.
					let [counter, linenum] = flag_count;
					// Increment and store values.
					flag_count = [linenum, counter + 1];
				}

				// Increment/set flag options counter.
				flag_count_options = [line_num, 0];

				// When parsing passes reset the index so that on the next
				// iteration it continues with the newline character.
				i = result.nl_index - 1;
			} else if (line_type === "flag_option") {
				// Parse line.
				let result = pflagoption(
					contents,
					i,
					l,
					line_num,
					line_fchar,
					indentation
				);

				// Check result for parsing issues (errors/warnings).
				verify(result);

				// Get result value.
				let value = result.value[0];

				// If flag chain exists add flag option and increment counter.
				let chain = lookup[currentchain];
				if (chain && value) {
					chain.push(`${currentflag}=${value}`);

					// Increment flag option counter.
					if (flag_count_options) {
						// Get values before incrementing.
						let [counter, linenum] = flag_count_options;
						// Increment and store values.
						flag_count_options = [linenum, counter + 1];
					}
				}

				// When parsing passes reset the index so that on the next
				// iteration it continues with the newline character.
				i = result.nl_index - 1;
			} else if (line_type === "close_parenthesis") {
				// Opening flag must be set else this ')' is unmatched.
				brace_check("unmatched", ")");
				// If command chain's flag array is empty give warning.
				if (flag_count_options && !flag_count_options[1]) {
					brace_check("empty", "parentheses");
				}
				// Clear flag.
				flag_count_options = null;

				// Parse line.
				let result = pbrace(contents, i, l, line_num, line_fchar);

				// Check result for parsing issues (errors/warnings).
				verify(result);

				// Reset flags.
				currentflag = null;
				last_open_pr = null;

				// When parsing passes reset the index so that on the next
				// iteration it continues with the newline character.
				i = result.nl_index - 1;
			} else if (line_type === "close_bracket") {
				// Opening flag must be set else this ']' is unmatched.
				brace_check("unmatched", "]");
				// If command chain's flag array is empty give warning.
				if (flag_count && !flag_count[1]) {
					brace_check("empty", "brackets");
				}
				// Clear flag.
				flag_count = null;

				// Parse line.
				let result = pbrace(contents, i, l, line_num, line_fchar);

				// Check result for parsing issues (errors/warnings).
				verify(result);

				// Reset flags.
				currentchain = "";
				last_open_br = null;

				// When parsing passes reset the index so that on the next
				// iteration it continues with the newline character.
				i = result.nl_index - 1;
			} else if (line_type === "comment") {
				// Reset index to comment ending newline index.
				let la = lookahead(i, contents, r_nl);
				i = la.indices[1] - 1;
			}
		}
	}

	// Final unclosed brace checks.
	brace_check("unclosed", "[");
	brace_check("unclosed", "(");

	/**
	 * IIFE arrow function prints parser warnings.
	 *
	 * @return {undefined} - Nothing is returned.
	 *
	 * @resource [https://stackoverflow.com/a/8228308]
	 */
	(() => {
		// Order warnings by line number then issue.
		warnings = warnings.sort(function(a, b) {
			// [https://coderwall.com/p/ebqhca/javascript-sort-by-two-fields]
			// [https://stackoverflow.com/a/13211728]
			return a.line - b.line || a.index - b.index;
		});

		for (let i = 0, l = warnings.length; i < l; i++) {
			// Cache current loop item.
			issue(warnings[i], "warn");
		}
	})();

	console.log("");
	console.log(chalk.bold.blue("LOOKUP:"));
	console.log(lookup);
	console.log("");
	console.log(chalk.bold.blue("SETTINGS:"));
	console.log(settings);
	console.log("");
	console.log(chalk.bold.blue("NEWLINES:"));

	for (let i = 0, l = newlines.length; i < l; i++) {
		// Cache current loop item.
		let line = newlines[i];

		console.log(line);
	}
	console.log("");

	exit([]);

	// // Return generated acdef/config file contents.
	// return {
	// 	acdef: header
	// 		.concat(
	// 			merge(commandname, lookup, newlines).sort(function(a, b) {
	// 				return a.localeCompare(b);
	// 			})
	// 		)
	// 		.join("\n")
	// 		.replace(/\s*$/, ""),
	// 	config: config(settings, header)
	// };
};
