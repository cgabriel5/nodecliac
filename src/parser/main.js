"use strict";

// Require parsers.
const stripansi = require("strip-ansi");
const psetting = require("./p.setting.js");
const pcommand = require("./p.command.js");
const pbrace = require("./p.close-brace.js");
const pflagset = require("./p.flagset.js");
const pflagoption = require("./p.flagoption.js");
const pcomment = require("./p.comment.js");

// Require parser helpers.
const h = require("./h.highlighter.js");
const mkchain = require("./h.mkchain.js");
const shortcuts = require("./h.shortcuts.js");

// Get error checking functions.
const {
	issue,
	error: eerror,
	// Rename functions to later wrap.
	verify: everify,
	brace_check: ebc
} = require("./h.error.js");

module.exports = (
	contents,
	commandname,
	source,
	formatting,
	ignorecomments // When formatting should comments be ignored?
) => {
	// Vars - timers.
	let stime = process.hrtime(); // Store start time tuple array.

	// Vars - Main loop.
	let i = 0;
	let l = contents.length;

	// Vars - Line information.
	let line_num = 1; // y-index
	let line_fchar; // x-index
	let indentation = "";

	// Vars - General.
	let lookup = {};
	// Keep track of lookup size.
	let lk_size = 0;
	let settings = {};
	// Keep track of settings count.
	settings.count = 0;
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
	let r_start_line_char = /[-@a-zA-Z)\]#]/; // Starting line character.

	// Create error functions wrappers to add fixed parameters.
	let verify = result => {
		return everify(result, warnings, source);
	};
	let brace_check = (issue, brace_style) => {
		return ebc({
			issue,
			brace_style,
			last_open_br,
			last_open_pr,
			indentation,
			warnings,
			source
		});
	};
	let error = (...params) => {
		// Add source to parameters.
		params.push(source);
		// Run and return error function.
		return eerror.apply(null, params);
	};
	// Create parser wrapper to add fixed parameters.
	let parser = (pname, ...params) => {
		// Join fixed parameters with provided.
		params = [contents, i, l, line_num, line_fchar, h].concat(params);
		// Run parser function.
		return pname.apply(null, params);
	};

	/**
	 * Store line and its type. Mainly used to reset new line counter.
	 *
	 * @param  {string} string - The line to add to formatted array.
	 * @param  {string} type - The line's line type.
	 * @param  {array} type - Array: [tab char, indentation amount].
	 * @return {undefined} - Nothing is returned.
	 */
	let preformat = (line, type, indentation) => {
		// Ignore comments when 'ignore-comments' is set.
		if (ignorecomments && type === "comment") {
			return;
		}

		// Reset format new line counter.
		preformat.nl_count = 0;
		// Add line to formatted array.
		preformat.lines.push([line, type, indentation]);
	};
	// Vars -  Pre-formatting (attached to function).
	preformat.lines = []; // Store lines before final formatting.
	preformat.nl_count = 0; // Store new line count.

	// ACMAP file header.
	let header = [
		`# THIS FILE IS AUTOGENERATED —— DO NOT EDIT FILE DIRECTLY.`,
		`# ${new Date()};${Date.now()}`,
		`# nodecliac definition mapfiles: ~/.nodecliac/defs/\n`
	];

	// Main loop. Loops over each character in acmap.
	for (; i < l; i++) {
		// Cache current/previous/next chars.
		let char = contents.charAt(i);
		// let pchar = contents.charAt(i - 1);
		let nchar = contents.charAt(i + 1);

		// Check if \r?\n newline sequence.
		if ((char === "\r" && nchar === "\n") || char === "\n") {
			// Exclude consecutive new lines.
			if (preformat.nl_count < 2) {
				preformat.nl_count++;
				// Add line to formatted text.
				preformat.lines.push(["\n", "nl"]);
			}

			// Reset vars.
			line_type = null;
			indentation = "";
			line_num++; // Increment line counter.
			line_fchar = null; // Reset line char index.

			// Note: The line type will get switched to "command_setter"
			// after extracting the command chain. However, when the command
			// chain is not assigned flags the command chain needs to be
			// cleared to catch any flags not contained within [].
			if (line_type === "command_setter") {
				currentchain = "";
			}

			continue;
		}

		// Store index of first character of current line to keep track of
		// the x-index character position.
		if (!line_fchar) {
			line_fchar = i;
		}

		// Determine the lines type to parse line accordingly.
		if (!line_type) {
			// If the current character is a space then continue.
			if (r_whitespace.test(char)) {
				indentation += char;
				continue;
			}

			// Line must begin with following start-of-line character:
			// @       → Setting.
			// #       → Comment.
			// a-zA-Z  → Command chain.
			// -       → Flag.
			// '- '    → Flag option (ignore quotes).
			// )       → Closing flag set.
			// ]       → Closing long-flag form.

			// If current flag is set only comments, flag options, and
			// closing parenthesis are allowed.
			if (currentflag) {
				switch (char) {
					case ")":
						line_type = "close-parenthesis";
						break;
					case "#":
						line_type = "comment";
						break;
					default:
						line_type = "flag-option";
				}
			} else {
				// Char must be an allowed starting char.
				if (!r_start_line_char.test(char)) {
					// Character index will be indentation.length + 1.
					error(char, 0, line_num, indentation.length + 1);
				}

				// Set line start type.
				// RegExp Switch case: [https://stackoverflow.com/a/2896642]
				switch (true) {
					case char === "@":
						line_type = "setting";
						break;
					case char === "#":
						line_type = "comment";
						break;
					case char === "]":
						line_type = "close-bracket";
						break;
					case char === "-":
						// If flag is set we are getting flag options.
						line_type = currentflag ? "flag-option" : "flag-set";

						// If command chain doesn't exist but a flag-set or
						// option was detected the line was illegally declared.
						if (!currentchain) {
							// Check for improperly declared flag/option.
							if (/[- \t]/.test(nchar)) {
								error("", nchar === "-" ? 4 : 3, line_num, 0);
							} else {
								// General error - invalid line.
								error("", 5, line_num, 0);
							}
						}

						break;
					case char === ")":
						line_type = "close-parenthesis";
						break;
					case r_letter.test(char):
						line_type = "command";

						// If a current chain flag is set then another chain
						// cannot be parsed. This means the chain is nested.
						if (currentchain) {
							error("", 1, line_num, 0);
						}

						break;
				}

				// Indentation/whitespace checks.
				if (indentation) {
					// Following commands cannot begin with any whitespace.
					if (/(setting|command)/.test(line_type)) {
						// Line cannot begin begin with whitespace.
						error("", 6, line_num, 0);
					}

					// Give warning for mixed whitespace
					if (/ /.test(indentation) && /\t/.test(indentation)) {
						// Add warning to warnings.
						warnings.push({
							line: line_num,
							index: 0,
							reason: `Mixed whitespace characters.`,
							// Add key to denote file giving issue.
							source: "p.main.js"
						});
					}
				}
			}
		}

		// Run logic for each line type.
		switch (line_type) {
			case "setting":
				{
					// Parse and verify line.
					let result = verify(parser(psetting, settings));

					// Reset index to start at newline on next iteration.
					i = result.nl_index - 1;

					// Store setting/value pair (Note: Remove ANSI color).
					settings[stripansi(result.name)] = result.value;
					// Increment settings count.
					settings.count++;

					// Add line to format later.
					preformat(`${result.name} = ${result.value}`, "setting");
				}

				break;
			case "command":
				{
					// Check for an unclosed '['.
					brace_check("unclosed", "[");

					// Parse and verify line.
					let result = verify(parser(pcommand));

					// Reset index to start at newline on next iteration.
					i = result.nl_index - 1;

					// Get command chain.
					let cc = result.chain;
					// let value = result.value;
					// Get opening brace index.
					let br_index = result.br_open_index;

					// Store command chain.
					if (!lookup[cc]) {
						lookup[cc] = new Set();
						lk_size++;
					}
					// Store current command chain.
					currentchain = cc;

					// For non flag set one-liners.
					if (result.brstate) {
						// Add line to format later.
						preformat(`${currentchain} = [`, "command");

						// If brackets are empty set flags.
						if (result.brstate === "closed") {
							// Reset flags.
							currentchain = "";
							last_open_br = null;

							// Add line to format later.
							preformat(`]`, "command");
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

							// Add line to format later.
							preformat(
								`${result.chain}${
									flags.length ? ` = ${flags.join("|")}` : ""
								}`,
								"command"
							);

							// Add each flag set to its command chain.
							for (let j = 0, ll = flags.length; j < ll; j++) {
								// Cache current loop item.
								let flag = flags[j].trim();

								// Skip empty flags.
								if (!/^-{1,}$/.test(flag)) {
									chain.add(flag);
								}
							}
						}
					}
				}

				break;
			case "flag-set":
				{
					// Check for an unclosed '('.
					brace_check("unclosed", "(");

					// Parse and verify line.
					let result = verify(parser(pflagset, indentation));

					// Breakdown flag.
					let hyphens = result.symbol;
					let flag = result.name;
					let setter = result.assignment;
					let values = result.value;
					let values_len = values.length;
					let fval = values[0]; // Get first value.
					// let special = result.special;
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

					// Add line to format later.
					preformat(
						// TODO: Simplify/clarify logic.
						`${hyphens}${flag}${
							!setter
								? ""
								: !values_len
								? `${setter}()`
								: values_len && fval === "("
								? `${setter}(`
								: `${setter}`
							// : values_len && fval === ""
							// ? `${setter}`
						}`,
						"flag-set",
						1
					);

					// Add to lookup table if not already.
					let chain = lookup[currentchain];
					if (chain) {
						// Add flag itself to lookup table > command chain.
						chain.add(`${hyphens}${flag}${setter}`);

						// If not an opening brace then add values.
						if (!isopeningpr && fval && values_len) {
							// Formatted flag values list string.
							let flist = "";

							// Check whether first value is a command-flag.
							let is_cmd_flag = fval.startsWith("$(");

							// Loop over values and add to lookup table.
							for (let i = 0, l = values_len; i < l; i++) {
								// Cache current loop item.
								let value = values[i];

								// Skip empty value.
								if (!value) {
									continue;
								}

								// Store value in formatted list.
								flist += `${value}${
									values_len - 1 !== i ? " " : ""
								}`;

								// Extract '=' from assignment.
								let cassignment = setter.charAt(0);

								// Add to lookup table > command chain.
								chain.add(
									`${hyphens}${flag}${cassignment}${value}`
								);
							}

							// Add line to formatted text.
							if (flist) {
								// TODO: Simplify/clarify logic.

								// Determine whether to wrap list: '()'.
								let wrap = !(is_cmd_flag || values_len === 1);

								// Get last formatted line in array. It should
								// be the flag set's flag.
								let last_fline =
									preformat.lines[preformat.lines.length - 1];
								// Add to last line in formatted array.
								last_fline[0] = `${last_fline[0]}${
									wrap ? "(" : ""
								}${flist}${wrap ? ")" : ""}`;
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

					// Reset index to start at newline on next iteration.
					i = result.nl_index - 1;
				}

				break;
			case "flag-option":
				{
					// Parse and verify line.
					let result = verify(parser(pflagoption, indentation));

					// Get result value.
					let value = result.value[0];

					// If flag chain exists add flag option and increment counter.
					let chain = lookup[currentchain];
					if (chain && value) {
						// Add line to format later.
						preformat(`- ${value}`, "flag-option", 2);

						chain.add(`${currentflag}=${value}`);

						// Increment flag option counter.
						if (flag_count_options) {
							// Get values before incrementing.
							let [counter, linenum] = flag_count_options;
							// Increment and store values.
							flag_count_options = [linenum, counter + 1];
						}
					}

					// Reset index to start at newline on next iteration.
					i = result.nl_index - 1;
				}

				break;
			case "close-parenthesis":
				{
					// Opening flag must be set else this ')' is unmatched.
					brace_check("unmatched", ")");
					// If command chain's flag array is empty give warning.
					if (flag_count_options && !flag_count_options[1]) {
						brace_check("empty", "parentheses");
					}
					// Clear flag.
					flag_count_options = null;

					// Parse and verify line.
					let result = verify(parser(pbrace));

					// Reset flags.
					currentflag = null;
					last_open_pr = null;

					// Add line to format later.
					preformat(`)`, "close-brace", 1);

					// Reset index to start at newline on next iteration.
					i = result.nl_index - 1;
				}

				break;
			case "close-bracket":
				{
					// Opening flag must be set else this ']' is unmatched.
					brace_check("unmatched", "]");
					// If command chain's flag array is empty give warning.
					if (flag_count && !flag_count[1]) {
						brace_check("empty", "brackets");
					}
					// Clear flag.
					flag_count = null;

					// Parse and verify line.
					let result = verify(parser(pbrace));

					// Reset flags.
					currentchain = "";
					last_open_br = null;

					// Add line to format later.
					preformat(`]`, "close-brace");

					// Reset index to start at newline on next iteration.
					i = result.nl_index - 1;
				}

				break;
			case "comment":
				{
					// Parse and verify line.
					let result = verify(parser(pcomment));

					// Add line to format later.
					preformat(
						`${result.comment}`,
						"comment",
						// Determine format indentation level.
						currentflag ? 2 : currentchain ? 1 : undefined
					);

					// Reset index to start at newline on next iteration.
					i = result.nl_index - 1;
				}

				break;
		}
	}

	// Final unclosed brace checks.
	brace_check("unclosed", "[");
	brace_check("unclosed", "(");

	// Expand shortcuts and make any children command chains.
	for (let chain in lookup) {
		// Loop through lookup table.
		if (lookup.hasOwnProperty(chain)) {
			// Get flags.
			let flags = lookup[chain];

			// Expand shortcuts in command chain.
			let sc = shortcuts(chain);
			// Chains containing shortcuts will return a populated array.
			if (sc.length) {
				// Loop over each expanded chain to make
				for (let i = 0, l = sc.length; i < l; i++) {
					// Cache current loop item.
					let shortcut = sc[i];
					// Create children command chains.
					mkchain(shortcut, flags, lookup);

					// Finally, delete original chain from object.
					delete lookup[chain];
				}
			} else {
				// Create children command chains.
				mkchain(chain, flags, lookup);
			}
		}
	}

	// Log any warnings.
	require("./h.warnings.js")(warnings, issue, source);

	// Return generated acdef, config, and formatted file contents.
	return {
		acdef: require("./h.acdef.js")(commandname, lookup, lk_size, header),
		config: require("./h.config.js")(settings, header),
		formatted: require("./h.formatter.js")(
			preformat.lines,
			formatting,
			ignorecomments
		),
		time: process.hrtime(stime) // Return end time tuple array.
	};
};
