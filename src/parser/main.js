"use strict";

// Setup app global variables.
const globals = require("./h.globals.js");

// Require parsers.
const psetting = require("./p.setting.js");
const pvariable = require("./p.variable.js");
const pcommand = require("./p.command.js");
const pbrace = require("./p.close-brace.js");
const pflagset = require("./p.flagset.js");
const pflagoption = require("./p.flagoption.js");
const pcomment = require("./p.comment.js");

// Require parser helpers.
const mkchain = require("./h.mkchain.js");
const shortcuts = require("./h.shortcuts.js");
const s = globals.set("stripansi", require("strip-ansi"));
const { formatter, preformat } = require("./h.formatter.js");
const h = globals.set("highlighter", require("./h.highlighter.js"));

// Get error checking functions.
const {
	issue,
	error: eerror,
	// Rename functions to later wrap.
	verify: everify,
	brace_check: ebc,
	orphaned_cmddel_check
} = require("./h.error.js");

module.exports = (
	contents,
	commandname,
	source,
	formatting,
	highlight,
	trace,
	nowarn,
	stripcomments // When formatting should comments be removed?
) => {
	// Store arguments for quick access later.
	globals.set("string", contents);
	globals.set("commandname", commandname);
	globals.set("source", source);
	globals.set("formatting", formatting);
	globals.set("highlight", highlight);
	globals.set("stripcomments", stripcomments);
	globals.set("trace", trace);

	// Vars - timers.
	let stime = process.hrtime(); // Store start time tuple array.

	// Vars - Main loop.
	let i = 0;
	let l = globals.set("l", contents.length);

	// Vars - Line information.
	let line_num = 1; // y-index
	let line_fchar; // x-index
	let indentation = "";

	// Vars - General.
	let lookup = globals.set("lookup", {});
	// Keep track of lookup size.
	let lk_size = 0;
	let settings = globals.set("settings", {});
	let hsettings = globals.set("hsettings", {});
	// Keep track of settings size/count.
	settings.__count__ = 0;
	let warnings = globals.set("warnings", []);
	// Track keywords.
	let keywords = globals.set("keywords", {});
	let hkeywords = globals.set("hkeywords", {});
	// Keep track of keyword size/count.
	keywords.__count__ = 0;
	// Track variables.
	let variables = globals.set("variables", {});
	let hvariables = globals.set("hvariables", {});
	variables.__count__ = 0;
	// Hold delimited chains.
	let chains = globals.set("chains", []);

	// Vars - Parser flags.
	let line_type; // Store current type of line being parsed.
	let currentflag; // Store flag name of currently parsed flag list.
	let hcurrentflag; // Highlighted version.
	let currentchain; // Store current command chain.
	let hcurrentchain; // Highlighted version.

	// Vars - Tracking.
	let last_open_br; // Track open/closing brackets.
	let last_open_pr; // Track open/closing parentheses.
	let flag_count; // Track command's flag count.
	let flag_count_options; // Track flag's option count.
	let skip_nl = false; // Whether to skip adding a preformat newline.
	let last_delimited_command; // Track last delimiter command chain.

	// RegExp patterns:
	let r_letter = /[a-zA-Z]/; // Letter.
	let r_whitespace = /[ \t]/; // Whitespace.
	let r_start_line_char = /[-@a-zA-Z)\]\$#]/; // Starting line character.

	// Create error functions wrappers to add fixed parameters.
	let verify = result => {
		return everify(result, source);
	};
	let brace_check = (issue, brace_style) => {
		// Set globals to access in parser.
		globals.set("indentation", indentation);
		// Run and return error function.
		return ebc({ issue, brace_style, last_open_br, last_open_pr });
	};
	let error = (...params) => {
		// Add source to parameters.
		params.push(source);
		// Run and return error function.
		return eerror.apply(null, params);
	};
	// Create parser wrapper to set global variables.
	let parser = parser_name => {
		// Set globals to access in parser.
		globals.set("i", i);
		globals.set("line_num", line_num);
		globals.set("line_fchar", line_fchar);
		// ACMAP file header.
		globals.set(
			"header",
			`# DON'T EDIT FILE —— GENERATED: ${new Date()}(${Date.now()})\n`
		);

		// Run parser.
		return parser_name();
	};

	// Main loop. Loops over each character in acmap.
	for (; i < l; i++) {
		// Cache current/previous/next chars.
		let char = contents.charAt(i);
		// let pchar = contents.charAt(i - 1);
		let nchar = contents.charAt(i + 1);

		// Check if \r?\n newline sequence.
		if ((char === "\r" && nchar === "\n") || char === "\n") {
			// Exclude consecutive new lines.
			if (preformat.nl_count < 2 && !skip_nl) {
				preformat.nl_count++;
				// Add line to formatted text.
				preformat.lines.push(["\n", "nl"]);
				preformat.hlines.push(["\n", "nl"]);
			}

			// Reset vars.
			line_type = null;
			indentation = "";
			line_num++; // Increment line counter.
			line_fchar = null; // Reset line char index.
			skip_nl = false;

			// Note: The line type will get switched to "command_setter"
			// after extracting the command chain. However, when the command
			// chain is not assigned flags the command chain needs to be
			// cleared to catch any flags not contained within [].
			if (line_type === "command_setter") {
				currentchain = "";
				hcurrentchain = "";
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
					case char === "$":
						line_type = "variable";
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
							// When inside a command chain's flag definitions
							// all lines must start off with hyphens to denote
							// they are flag definitions. However with the
							// new 'default' keyword this means we must now
							// also allow letters. Would it be better to
							// limit char to a character white-list?
							if (/[a-z]/.test(char)) {
								// Reset the line type.
								line_type = "flag-option";

								// Stop further logic.
								break;
							}

							// Give error for all other characters.
							error("", 1, line_num, 0);
						}

						break;
				}

				// Indentation/whitespace checks.
				if (indentation) {
					// Following commands cannot begin with any whitespace.
					if (/(setting|variable|command)/.test(line_type)) {
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

		// For following line types run orphaned delimiter chain check.
		if (chains.length && !/(command|comment)/.test(line_type)) {
			// Check if delimited command was left orphaned.
			orphaned_cmddel_check(last_delimited_command);
		}

		// Run logic for each line type.
		switch (line_type) {
			case "setting":
				{
					// Parse and verify line.
					let result = verify(parser(psetting));

					// Reset index to start at newline on next iteration.
					i = result.nl_index - 1;

					// Get setting components.
					let name = result.name;
					let hname = result.h.name;
					let value = result.value;
					let hvalue = result.h.value;

					// Store setting/value pair (Note: Remove ANSI color).
					settings[name] = value;
					hsettings[hname] = hvalue;
					// Increment settings size/count.
					settings.__count__++;

					// Add line to format later.
					preformat(
						`${name}${value ? " = " + value : ""}`,
						`${hname}${hvalue ? " = " + hvalue : ""}`,
						"setting"
					);
				}

				break;
			case "variable":
				{
					// Parse and verify line.
					let result = verify(parser(pvariable));

					// Reset index to start at newline on next iteration.
					i = result.nl_index - 1;

					// Get variable components.
					let name = result.name;
					let hname = result.h.name;
					let value = result.value;
					let hvalue = result.h.value;

					// Store variable/value pair.
					variables[name] = value;
					hvariables[hname] = hvalue;
					// Increment variables size/count.
					variables.__count__++;

					// Add line to format later.
					preformat(
						`${name}${value ? " = " + value : ""}`,
						`${hname}${hvalue ? " = " + hvalue : ""}`,
						"variable"
					);
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
					let hcc = result.h.chain;
					// Get opening brace index.
					let br_index = result.br_open_index;
					let brstate = result.brstate;
					let delimiter = result.delimiter;

					// Store result object in chains array.
					chains.push(result);

					// If command is being delimited stop further processing.
					if (delimiter) {
						// Store delimiter line + opening bracket index.
						last_delimited_command = [
							line_num,
							result.delimiter_index
						];

						// Since we are skipping further process we also need
						// to skip adding the line's ending newline character.
						skip_nl = true;
						break;
					}

					// When command-chain has assignment, clear flag.
					if (result.assignment) {
						last_delimited_command = null;
					}

					// If a oneliner was just parsed then add its flagsets
					// to the child command chains objects so they share
					// them. Basically, add flagsets from command chain with
					// assignment to its delimited sibling command chains.
					if (result.is_oneliner) {
						// Get last command-chain's flag sets.
						let flags = result.flagsets;
						let hflags = result.hflagsets;

						// Note: Since the high-order array function 'map'
						// returns a new array we need to reset the global
						// "chain" variable as it will get dereferenced
						chains = globals.set(
							"chains",
							chains.map(obj => {
								// Attach flags from (current) chain with
								// assignment to its delimited sibling chains.
								obj.flagsets = flags;
								obj.hflagsets = hflags;
								return obj;
							})
						);
					}

					// Loop over delimited command chain result objects.
					for (let i = 0, l = chains.length; i < l; i++) {
						// Cache current loop item.
						let result = chains[i];

						// Get command chain.
						let cc = result.chain;
						let hcc = result.h.chain;
						// Get opening brace index.
						let br_index = result.br_open_index;
						let brstate = result.brstate;

						// Store command chain.
						if (!lookup[cc]) {
							// Add to lookup.
							let set = new Set();
							// Add highlight set.
							set.__h = new Set();
							// Attach set to chain.
							lookup[cc] = set;
							// Increment lookup size.
							lk_size++;
						}
						// Store current command chain.
						currentchain = cc;
						hcurrentchain = hcc;

						// For non flag set one-liners.
						if (brstate) {
							// Add line to format later.
							preformat(
								`${currentchain} = [`,
								`${hcurrentchain} = [`,
								"command"
							);

							// If brackets are empty set flags.
							if (brstate === "closed") {
								// Reset flags.
								currentchain = "";
								hcurrentchain = "";
								last_open_br = null;

								// Add line to format later.
								preformat("]", "]", "command");
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
							hcurrentchain = "";

							// Store flagsets with its command chain in lookup table.
							let chain = lookup[result.chain];
							if (chain) {
								// Get flag sets.
								let flags = result.flagsets;
								let hflags = result.hflagsets;

								// For delimited command flags.
								if (result.delimiter) {
									// Add line to format later.
									preformat(`${cc},`, `${hcc},`, "command");

									// Add line to formatted text.
									preformat.lines.push(["\n", "nl"]);
									preformat.hlines.push(["\n", "nl"]);
								} else {
									// Add line to format later.
									preformat(
										`${cc}${
											flags.length
												? ` = ${flags.join("|")}`
												: ""
										}`,
										`${hcc}${
											hflags.length
												? ` = ${hflags.join("|")}`
												: ""
										}`,
										"command"
									);
								}

								// Add each flag set to its command chain.
								for (
									let j = 0, ll = flags.length;
									j < ll;
									j++
								) {
									// Cache current loop item.
									let flag = flags[j].trim();
									let hflag = hflags[j].trim();

									// Skip empty flags.
									if (!/^-{1,}$/.test(flag)) {
										chain.add(flag);
										chain.__h.add(hflag);
									}
								}
							}
						}
					}

					// Clear chains array to not pass delimited command chains.
					if (!delimiter) {
						if (!brstate || brstate !== "open") {
							// Clear chains array.
							chains.length = 0;
							// Clear flag.
							last_delimited_command = null;
						}
					}
				}

				break;
			case "flag-set":
				{
					// Check for an unclosed '('.
					brace_check("unclosed", "(");

					// Parse and verify line.
					let result = verify(parser(pflagset));

					// Breakdown flag.
					let hyphens = result.symbol;
					let flag = result.name;
					let hflag = result.h.name;
					let setter = result.assignment;
					let values = result.args;
					let hvalues = result.h.hargs;
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
						hcurrentflag = `${hyphens}${hflag}`;
					}

					// Generate the formatted assignment string.
					let fassignment =
						// TODO: Simplify/clarify logic.
						`${
							!setter
								? ""
								: !values_len
								? `${setter}()`
								: values_len && fval === "("
								? `${setter}(`
								: `${setter}`
							// : values_len && fval === ""
							// ? `${setter}`
						}`;
					// Add line to format later.
					preformat(
						`${hyphens}${flag}${fassignment}`,
						`${hyphens}${hflag}${fassignment}`,
						"flag-set",
						1
					);

					// Add to lookup table if not already.
					for (let i = 0, l = chains.length; i < l; i++) {
						// Cache current loop item.
						let result = chains[i];
						let chain = lookup[result.chain];

						if (chain) {
							// Get the highlighted set.
							let hchain = chain.__h;

							// Add flag itself to lookup table > command chain.
							chain.add(`${hyphens}${flag}${setter}`);
							// Add highlighted version.
							hchain.add(`${hyphens}${hflag}${setter}`);

							// If not an opening brace then add values.
							if (!isopeningpr && fval && values_len) {
								// Formatted flag values list string.
								let flist = "";
								let hflist = "";

								// Check whether first value is a command-flag.
								let is_cmd_flag = fval.startsWith("$(");

								// Loop over values and add to lookup table.
								for (let i = 0, l = values_len; i < l; i++) {
									// Cache current loop item.
									let value = values[i];
									// Get highlighted value.
									let hvalue = hvalues[i];

									// Skip empty value.
									if (!value) {
										continue;
									}

									// Store value in formatted list.
									flist += `${value}${
										values_len - 1 !== i ? " " : ""
									}`;
									// Store value in formatted list.
									hflist += `${hvalue}${
										values_len - 1 !== i ? " " : ""
									}`;

									// Extract '=' from assignment.
									let cassignment = setter.charAt(0);

									// Add to lookup table > command chain.
									chain.add(
										`${hyphens}${flag}${cassignment}${value}`
									);
									// Add highlighted version.
									hchain.add(
										`${hyphens}${hflag}${cassignment}${hvalue}`
									);
								}

								// Add line to formatted text.
								if (flist) {
									// TODO: Simplify/clarify logic.

									// Determine whether to wrap list: '()'.
									let wrap = !(
										is_cmd_flag || values_len === 1
									);

									// Get last formatted line in array. It should
									// be the flag set's flag.
									let last_fline =
										preformat.lines[
											preformat.lines.length - 1
										];
									// Add to last line in formatted array.
									last_fline[0] = `${last_fline[0]}${
										wrap ? "(" : ""
									}${flist}${wrap ? ")" : ""}`;

									// Get last formatted line in array. It should
									// be the flag set's flag.
									let hlast_fline =
										preformat.hlines[
											preformat.hlines.length - 1
										];
									// Add to last line in formatted array.
									hlast_fline[0] = `${hlast_fline[0]}${
										wrap ? "(" : ""
									}${hflist}${wrap ? ")" : ""}`;
								}
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
					let result = verify(parser(pflagoption));

					// Get result value(s).
					let values = result.value;
					let value = values[0]; // Get first value.

					// If flag chain exists add flag option and increment counter.
					let chain = lookup[currentchain];
					if (chain && value) {
						//
						for (let i = 0, l = chains.length; i < l; i++) {
							// Cache current loop item.
							let r = chains[i];
							let currentchain = r.chain;

							let chain = lookup[currentchain];

							// Get highlighted version.
							let hvalue = values.hargs[0];
							// Get keyword.
							let keyword = result.keyword;

							// For keyword declarations.
							if (keyword) {
								// Get highlighted/non-highlighted keywords.
								let [, hkeyword] = keyword;
								keyword = keyword[0];

								// Only add for the last loop iteration, the
								// chain where the fall back was attached to.
								if (l - 1 === i) {
									// Add line to format later.
									preformat(
										`${keyword} ${value}`,
										`${hkeyword} ${hvalue}`,
										keyword,
										1
									);
								}

								// Store setting/value pair (Note: Remove ANSI color).
								keywords[currentchain] = [keyword, value];
								hkeywords[currentchain] = [hkeyword, hvalue];
								// Increment keyword size/count.
								keywords.__count__++;
							}
							// Actual flag options.
							else {
								// Add line to format later.
								preformat(
									`- ${value}`,
									`- ${hvalue}`,
									"flag-option",
									2
								);

								// Add to lookup table > command chain.
								chain.add(`${currentflag}=${value}`);
								// Add highlighted version.
								chain.__h.add(`${hcurrentflag}=${hvalue}`);

								// Increment flag option counter.
								if (flag_count_options) {
									// Get values before incrementing.
									let [counter, linenum] = flag_count_options;
									// Increment and store values.
									flag_count_options = [linenum, counter + 1];
								}
							}
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
					hcurrentflag = null;
					last_open_pr = null;

					// Add line to format later.
					preformat(")", ")", "close-brace", 1);

					// Reset index to start at newline on next iteration.
					i = result.nl_index - 1;
				}

				break;
			case "close-bracket":
				{
					// Always clean array after closing a long-flag.
					chains.length = 0;

					// Opening flag must be set else this ']' is unmatched.
					brace_check("unmatched", "]");
					// If command chain's flag array is empty give warning.
					// Also account for 'default' command declaration count.
					if (flag_count && !(flag_count[1] || keywords.__count__)) {
						brace_check("empty", "brackets");
					}
					// Clear flag.
					flag_count = null;

					// Parse and verify line.
					let result = verify(parser(pbrace));

					// Reset flags.
					currentchain = "";
					hcurrentchain = "";
					last_open_br = null;

					// Add line to format later.
					preformat("]", "]", "close-brace");

					// Reset index to start at newline on next iteration.
					i = result.nl_index - 1;
				}

				break;
			case "comment":
				{
					// Parse and verify line.
					let result = verify(parser(pcomment));

					// Determine format indentation level.
					let indent_level = currentflag
						? 2
						: currentchain
						? 1
						: undefined;

					// Add line to format later.
					preformat(
						`${result.comment}`,
						`${result.h.comment}`,
						"comment",
						indent_level
					);

					// Reset index to start at newline on next iteration.
					i = result.nl_index - 1;
				}

				break;
		}
	}

	// Check if delimited command was left orphaned.
	orphaned_cmddel_check(last_delimited_command);
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
	if (!nowarn) {
		require("./h.warnings.js")(issue);
	}

	// Return generated acdef, config, and formatted file contents.
	return {
		time: process.hrtime(stime), // Return end time tuple array.
		formatted: formatter(preformat),
		config: require("./h.config.js")(),
		keywords: require("./h.keywords.js")(),
		acdef: require("./h.acdef.js")(lk_size)
	};
};
