"use strict";

// Needed modules.
const path = require("path");
const chalk = require("chalk");
const { exit } = require("./utils.js");

module.exports = (contents, source) => {
	// Vars.
	// acmap file header.
	let header = [
		`# THIS FILE IS AUTOGENERATED —— DO NOT EDIT FILE DIRECTLY.`,
		`# ${new Date()};${Date.now()}`,
		`# nodecliac definition mapfiles: ~/.nodecliac/defs/\n`
	];
	let newlines = [];
	let placeholders = [];
	let lookup = {};
	// Store extracted settings in acmap file.
	let settings = {};

	/**
	 * Build acdef config file contents from extracted settings.
	 *
	 * @param  {object} settings - The settings object.
	 * @return {string} - The config file contents string.
	 */
	let config = settings => {
		// Store lines.
		let lines = [];

		// Loop over settings to build config.
		for (let setting in settings) {
			if (settings.hasOwnProperty(setting)) {
				lines.push(`${setting} = ${settings[setting]}`);
			}
		}

		// Add header to lines and return final lines.
		return header
			.concat(
				lines.sort(function(a, b) {
					return a.localeCompare(b);
				})
			)
			.join("\n")
			.replace(/\s*$/, "");
	};

	/**
	 * Parse string by spaces. Takes into account quotes strings with spaces.
	 *     Making sure to ignore those spaces. Also respects escaped characters.
	 *     Adapted from argsplit module.
	 *
	 * @param  {string} input - The string input to parse.
	 * @return {array} - Array containing the parsed items.
	 *
	 * @resource [https://github.com/evanlucas/argsplit]
	 * @resource - Other CLI input parsers:
	 *     [https://github.com/elgs/splitargs]
	 *     [https://github.com/vladimir-tikhonov/string-to-argv#readme]
	 *     [https://github.com/astur/arrgv]
	 *     [https://github.com/mccormicka/string-argv]
	 *     [https://github.com/adarqui/argparser-js]
	 */
	let argparser = input => {
		// Vars.
		let current = "";
		let quote_char = "";
		let args = [];

		// Return empty array when input is empty.
		if (!input || !input.length) {
			return args;
		}

		// Loop over every input char.
		for (let i = 0, l = input.length; i < l; i++) {
			// Cache current/previous/next chars.
			let c = input.charAt(i);
			let p = input.charAt(i - 1);
			// let n = input.charAt(i + 1);

			// Reset prev word for 1st char as bash gets the last char.
			if (i === 0) {
				p = "";
			}
			// else if (i === l - 1) {
			// 	// Reset next word for last char as bash gets the first char.
			// 	n = "";
			// }

			// If char is a space.
			if (c === " " && p !== "\\") {
				if (quote_char.length !== 0) {
					current += c;
				} else {
					if (current !== "") {
						args.push(current);
						current = "";
					}
				}
				// Non space chars.
			} else if ((c === '"' || c === "'") && p !== "\\") {
				if (quote_char !== "") {
					if (quote_char === c) {
						current += c;
						args.push(current);
						quote_char = "";
						current = "";
					} else {
						current += c;
						quote_char = c;
					}
				} else {
					current += c;
					quote_char = c;
				}
			} else {
				current += c;
			}
		}

		// Add the remaining word.
		if (current !== "") {
			args.push(current);
		}

		return args;
	};

	/**
	 * Checks whether braces are balanced.
	 *
	 * @param  {string} string - The string to check.
	 * @return {boolean} - True means balanced.
	 *
	 * @resource [https://codereview.stackexchange.com/a/46039]
	 */
	let is_balanced = string => {
		// Vars.
		let braces = "[]{}()";
		let stack = [];
		let brindex;

		/**
		 * Determine the line information (line and character) of where
		 *     the brace imbalance was found.
		 *
		 * @param  {number} index - The index of the imbalanced brace.
		 * @return {boolean|undefined} - Boolean (true) for when braces
		 *     are balanced. Otherwise, exit script and print imbalanced
		 *     brace error message.
		 */
		let lineinfo = index => {
			// Get the line/char information.
			let lines = string.substring(0, index + 1).split(/\r?\n/);

			// Return the line and character line information.
			return {
				line: lines.length,
				char: lines.pop().indexOf(string.charAt(index))
			};
		};

		// Loop over content.
		for (let i = 0, l = string.length; i < l; i++) {
			// Get index of current char. If index is not '-1'
			// then we have a brace character.
			brindex = braces.indexOf(string.charAt(i));

			// Skip loop iteration if not a brace character.
			if (!-~brindex) {
				continue;
			}

			// If brace is even get its closing brace.
			if (!(brindex % 2)) {
				// Store expected closing brace index to later
				// check against.
				stack.push({ brindex: brindex + 1, i });
			} else {
				// if (stack.pop().brindex !== brindex) {

				// If stack is empty this means there were no opening
				// braces but a close brace was detected so break.
				if (!stack.length) {
					stack.push({ brindex, i, noopen: true });
					break;
				}

				// If brindex is not even then we potentially have
				// a closing brace. Therefore, compare the stacks
				// last item's value (the stored closing brace index)
				// with the current loop's iteration char index. If
				// the indices do not match then braces are unbalanced.
				if (stack[stack.length - 1].brindex !== brindex) {
					break;
				}

				// Remove last brace info object if its the correct
				// closing brace.
				stack.pop();
			}
		}

		// If stack is empty, braces are balanced.
		if (!stack.length) {
			return true;
		} else {
			// Else the script is imbalanced. Exit and print message.

			// Get the last brace object.
			let last = stack.pop();
			let { line, char } = lineinfo(last.i);
			let brindex = last.brindex;

			// No opening brace.
			if (last.noopen) {
				exit([
					`${chalk.bold("Brace:")} Unopened '${braces.charAt(
						brindex
					)}' at ${chalk.bold(`${line}:${char}.`)}`
				]);
			} else {
				// No closing brace.
				exit([
					`${chalk.bold("Brace:")} Unclosed '${braces.charAt(
						brindex - 1
					)}' at ${chalk.bold(`${line}:${char}.`)}`
				]);
			}
		}
	};

	/**
	 * Expand shortcuts. For example, command.{cmd1|cmd2} will expand
	 *     to command.cmd1 and command.cmd2.
	 *
	 * @param  {string} line - The line with shortcuts to expand.
	 * @return {array} - Array containing the expand lines.
	 */
	let expand_shortcuts = line => {
		let flines = [];

		if (/{.*?}/.test(line)) {
			let shortcuts;

			// Place hold shortcuts.
			line = line.replace(/{.*?}/, function(match) {
				// Remove syntax decorations + whitespace.
				shortcuts = match.replace(/^{|}$/gm, "").split("|");

				for (let i = 0, l = shortcuts.length; i < l; i++) {
					// Cache current loop item.
					let sc = shortcuts[i];

					flines.push(line.replace(/{.*?}/, sc));
				}

				// Remove shortcut from line by returning anonymous placeholder.
				return "--PL";
			});
		}

		// Use function recursion to completely expand all shortcuts.
		let recursion = [];
		if (/{.*?}/.test(flines[0])) {
			for (let i = 0, l = flines.length; i < l; i++) {
				// Cache current loop item.
				let line = flines[i];

				recursion = recursion.concat(expand_shortcuts(line, true));
			}
		}
		if (recursion.length) {
			return recursion;
		}

		return flines;
	};

	/**
	 * Unexpand multi-line flag options.
	 *
	 * @param  {string} contents - The multi-line flag to unexpand.
	 * @return {string} - The flag unexpanded.
	 */
	let unexpand_mf_options = contents => {
		return (contents = contents.replace(
			/^\s*-{1,2}[a-z][a-z0-9-]*\s*=\*?\s*\([\s\S]*?\)/gim,
			function(match) {
				// Format options.

				// Check for multi-starred flag.
				let multiflag = match.includes("=*")
					? match.substring(0, match.indexOf("=*"))
					: "";

				// [https://stackoverflow.com/a/18515993]
				let lb_regexp = /\r?\n/;

				// If the match does not have line breaks, for example,
				// "--Wno-strict-overflow=(2 5)", normalize it.
				if (!lb_regexp.test(match)) {
					let eq_index = match.indexOf("=");
					let flag = match.substring(0, eq_index);
					// Get individual value options.
					let options = argparser(
						match.substring(eq_index + 2, match.length - 1)
					);
					options = options.length ? options.join("\n") : "";

					// Normalize to match long-form syntax.
					match = `${flag}=(\n${options}\n)`;
				}

				// Get flag name.
				let [, indentation, flag, options] = match.match(
					/^(\s*)(-{1,2}[a-z][a-z0-9-]*)\s*=\*?\s*\(([\s\S]*?)\)/im
				);

				// Turn options list into an array.
				options = options.trim().split(lb_regexp);

				// Store options. Add multi-flag if it exists.
				let options_list = multiflag ? [`${multiflag}=*`] : [];

				// Loop over options to remove duplicate option values.
				for (let i = 0, l = options.length; i < l; i++) {
					// Cache current loop item.
					let option = options[i].trim();

					// Remove flag multi-line option/value marker ('- ').
					option = option.replace(/^-\s*/, "");

					// Filter out duplicate option values.
					if (-~options_list.indexOf(option)) {
						continue;
					}
					options_list.push(`${indentation}${flag}=${option.trim()}`);
				}

				// Sort the options and return.
				return options_list
					.sort(function(a, b) {
						return a.localeCompare(b);
					})
					.join("\n");
			}
		));
	};

	/**
	 * Fill-in placeholded command flags with their original content.
	 *
	 * @param  {string} contents - The line with possible placeholders.
	 * @return {string} - The line with filled in command-flags.
	 */
	let fillin_ph_cmd_flags = contents => {
		// Place hold long-form flags.
		let r = /!CMDFLGS#\d{1,}/g;

		// If line does not contain placeholders skip it.
		if (!r.test(contents)) {
			return contents;
		}

		return (contents = contents.replace(r, function(match) {
			// Get command-string from placeholders array.
			match = placeholders[match.match(/\d+/g) * 1 - 1];

			// Get command/delimiter.
			let [, command, , del] = match.match(/^\$\((.*?)(,\s*(.*?))?\)$/);

			// Build command-string and return.
			return `$(${command}${del ? `,${del}` : ""})`;
		}));
	};

	/**
	 * Fill-in placeholded long-form flags with collapsed single line
	 *     containing the formated flags.
	 *
	 * @param  {string} contents - The line with possible placeholders.
	 * @return {string} - The filled line with collapsed and formatted flags.
	 */
	let fillin_ph_lf_flags = contents => {
		// Place hold long-form flags.
		let r = /--LFFPH#\d{1,}/g;

		// If line does not contain placeholders skip it.
		if (!r.test(contents)) {
			return contents;
		}

		return (contents = contents.replace(r, function(match) {
			// Get flags from placeholders array.
			match = placeholders[match.match(/\d+/g) * 1 - 1];

			// Format flags:

			// Remove syntax decorations and white space.
			let flags = match.replace(/^\s*\[\s*|\s*\]\s*$/gm, "");

			// Format flags.
			flags = flags.split("\n");
			let lists = {
				type1: [],
				type2: [],
				type3: {
					list: [],
					lookup: {}
				}
			};
			let t2list = lists.type2;
			let t3list = lists.type3.list;
			// let t3lkup = lists.type3.lookup;

			// Loop over flags and format.
			for (let i = 0, l = flags.length; i < l; i++) {
				// Cache current loop item.
				let flag = flags[i].trim();

				// Flag forms:
				// --flag             → type 1
				// --flag=            → type 2
				// --flag=*           → type 2
				// --flag=value       → type 3

				if (!flag.includes("=")) {
					// Flag forms:
					// --flag

					// Add flag if not already in list.
					if (!-~lists.type1.indexOf(flag)) {
						lists.type1.push(flag);
					}
				} else {
					// Flag forms:
					// --flag=, --flag=*, --flag=value

					// If in form → --flag=/--flag=*, add to list if not already.
					if (
						/^-{1,2}[a-z][a-z0-9-]*=\*?$/i.test(flag) &&
						!-~t2list.indexOf(flag)
					) {
						if (flag.endsWith("*")) {
							// If non-asterisk form has already been added, remove
							// it from the list.
							let fflag = flag.slice(0, -1);
							if (t2list.includes(fflag)) {
								// Remove it from the list.
								t2list.splice(t2list.indexOf(fflag), 1);
							}
						} else {
							// If asterisk form has been already added don't add
							// non-asterisk flag.
							if (t2list.includes(`${flag}*`)) {
								continue;
							}
						}

						t2list.push(flag);
					} else {
						// Flag forms:
						// --flag=value

						// Split into flag (key) and value.
						let eq_index = flag.indexOf("=");
						let key = flag.substring(0, eq_index);
						// let value = flag.substring(eq_index + 1);

						let fkey = `${key}=`;
						// Since this key has options make sure to also add the key
						// to the type 2 flags as well if not explicitly provided.
						if (
							!-~t2list.indexOf(fkey) &&
							!-~t2list.indexOf(`${fkey}*`)
						) {
							t2list.push(fkey);
						}

						// Add to type3 list.
						t3list.push(flag);

						//////////////////////////////////////////*
						// // If the flag has a value as an option. Join multiple
						// // flag options into a single-mega option.
						//
						// // Split into flag (key) and value.
						// let eq_index = flag.indexOf("=");
						// let key = flag.substring(0, eq_index);
						// let value = flag.substring(eq_index + 1);
						//
						// // Add flag if not already in list.
						// if (!t3lkup[key]) {
						// 	// Store value.
						// 	t3lkup[key] = [value];
						// } else {
						// 	// Else, flag is already in list. Just add the value.
						// 	t3lkup[key].push(value);
						// }
						//////////////////////////////////////////*
					}
				}
			}

			//////////////////////////////////////////*
			// // Combine all flags into a single line.
			// // Prep type3 flag types.
			// let obj = lists.type3.lookup;
			// for (let key in obj) {
			// 	if (obj.hasOwnProperty(key)) {
			// 		let fkey = `${key}=`;
			// 		// Since this key has options make sure to also add the key
			// 		// to the type 2 flags as well if not explicitly provided.
			// 		if (
			// 			!-~t2list.indexOf(fkey) &&
			// 			!-~t2list.indexOf(`${fkey}*`)
			// 		) {
			// 			t2list.push(fkey);
			// 		}
			//
			// 		let value = obj[key].join(" ");
			// 		// Add to type3 list.
			// 		t3list.push(`${key}=(${value})`);
			// 	}
			// }
			//////////////////////////////////////////*

			flags = lists.type1
				.concat(lists.type2, lists.type3.list)
				// [https://stackoverflow.com/a/16481400]
				.sort(function(a, b) {
					return a.localeCompare(b);
				})
				.join("|");

			return flags;
		}));
	};

	/**
	 * Create a lookup table to remove duplicate command chains. Duplicate
	 *     chains will have all their respective flag sets combined as well.
	 *
	 * @param  {string} line - The line do check.
	 * @return {undefined} - Nothing is returned.
	 */
	let dupecheck = line => {
		// Extract commandchain and flags.
		let sepindex = line.indexOf(" ");
		let commandchain = line.substring(0, sepindex);
		let flags = line.substring(sepindex + 1);

		// Check if command chain contains invalid characters.
		let r = /[^-._:a-zA-Z0-9\\/]/;
		if (r.test(commandchain)) {
			// Loop over command chain to highlight invalid character.
			let chars = [];
			let invalid_char_count = 0;
			for (let i = 0, l = commandchain.length; i < l; i++) {
				// Cache current loop item.
				let char = commandchain[i];

				// If an invalid character highlight.
				if (r.test(char)) {
					chars.push(chalk.bold.red(char));
					invalid_char_count++;
				} else {
					chars.push(char);
				}
			}

			// Plural output character string.
			let char_string = `character${invalid_char_count > 1 ? "s" : ""}`;

			// Invalid escaped command-flag found.
			exit([
				`${chalk.bold(
					"Invalid:"
				)} ${char_string} in command: ${chars.join("")}`,
				`Remove invalid ${char_string} to successfully parse acmap file.`
			]);
		}
		// Command must start with letters.
		if (!/^\w/.test(commandchain)) {
			exit([
				`${chalk.bold(
					"Invalid:"
				)} command '${commandchain}' must start with a letter.`,
				`Fix issue to successfully parse acmap file.`
			]);
		}

		// Normalize command chain. Replace unescaped '/' with '.' dots.
		commandchain = commandchain.replace(/([^\\]|^)\//g, "$1.");

		// Note: Create needed parent commandchain(s). For example, if the
		// current commandchain is 'a.b.c' we create the chains: 'a.b' and
		// 'a' if they do not exist. Kind of like 'mkdir -p'.
		// Parse command chain for individual commands.
		let cparts = [];
		let command = "";
		let command_string = "";
		let command_count = 0;
		for (let i = 0, l = commandchain.length; i < l; i++) {
			// Cache current loop characters.
			let char = commandchain.charAt(i);
			let pchar = commandchain.charAt(i - 1);
			let nchar = commandchain.charAt(i + 1);

			// If a dot or slash and it's not escaped.
			if (/(\.|\/)/.test(char) && pchar !== "\\") {
				// Push current command to parts array.
				cparts.push(command);

				// Track command path.
				command_string += command_count ? `.${command}` : command;
				// Add command path to lookup.
				if (!lookup[command_string]) {
					lookup[command_string] = [];
				}

				// Clear current command.
				command = "";
				command_count++;
				continue;
			} else if (char === "\\" && /(\.|\/)/.test(nchar)) {
				// Add separator to current command since it's used as
				// an escape sequence.
				command += `\\${nchar}`;
				i++;
				continue;
			}

			// Append current char to current command string.
			command += char;
		}
		// // Add remaining command if string is not empty.
		// if (command) { cparts.push(command); }

		// Check whether flag set is empty.
		let flags_empty = flags === "--";

		// Store in lookup table.
		if (!lookup[commandchain]) {
			lookup[commandchain] = flags_empty ? [] : [flags];
		} else {
			if (!flags_empty) {
				lookup[commandchain].push(
					`${lookup[commandchain].length ? "|" : ""}${flags}`
				);
			}
		}
	};

	// Exit if file is empty.
	if (!contents.trim().length) {
		exit([
			`Action aborted. ${chalk.bold(
				path.relative(process.cwd(), source)
			)} is empty.`
		]);
	}

	// Braces must be balanced.
	is_balanced(contents);

	// Initial content modifications.
	contents = contents
		// Remove comments.
		.replace(/# .*?$/gm, "")
		// Remove empty lines and collapse trailing line white space.
		.replace(/(^\s*|^\s*$)/gm, "")
		.replace(/\s*$/, "")
		// Place hold command-flags.
		// RegExp Look-around assertions: [https://stackoverflow.com/a/3926546]
		// .replace(/(?<=[^\\])\$\([\s\S]*?[^\\]\)/g, function(match) {
		.replace(/.?\$\([\s\S]*?[^\\]\)/g, function(match) {
			// If first char is a slash, exit script and give warning.
			let fchar = match.charAt(0);
			if (fchar === "\\") {
				// Invalid escaped command-flag found.
				exit([
					`${chalk.bold("Invalid:")} command-flag '${match}' found.`,
					"Unescape command-flag or remove all together to successfully parse acmap file."
				]);
			}

			// If the first character is not '$' then remove it before
			// storing it in placeholders array.
			if (fchar !== "$") {
				match = match.substring(1);
			}

			// Process and store flag placeholders.
			placeholders.push(match);
			// Return placeholder marker.
			return `${fchar}!CMDFLGS#${placeholders.length}`;
		})
		// Place hold long-form flags.
		.replace(/\[[\s\S]*?\]/g, function(match) {
			// Process and store flag placeholders.
			placeholders.push(unexpand_mf_options(match));
			// Return placeholder marker.
			return `--LFFPH#${placeholders.length}`;
		});

	// Exit if file is empty.
	if (!contents.trim().length) {
		exit([
			`Action aborted. ${chalk.bold(
				path.relative(process.cwd(), source)
			)} is empty.`
		]);
	}

	// Go line by line:
	let lines = contents.split("\n");
	for (let i = 0, l = lines.length; i < l; i++) {
		// Cache current loop item.
		let line = lines[i].trim();

		// Check for settings lines.
		if (line.charAt(0) === "@") {
			// Parse line to get setting name and value.
			let eq_index = line.indexOf("=");
			let sname = line.substring(0, eq_index).trim();
			// Unquote values?
			let svalue = line.substring(eq_index + 1).trim();

			// Add to lookup table.
			settings[sname] = svalue;

			// Skip further logic to prevent from storing line.
			continue;
		}

		// Check whether flags were provided.
		if (!line.includes(" --")) {
			line += " --";
		}
		// Remove all equal-sign pointers.
		line = line.replace(/\s{1,}=\s*/g, " ");
		// Fill back in long form flag placeholders.
		line = fillin_ph_lf_flags(line);
		// Fill back in command flags placeholders.
		line = fillin_ph_cmd_flags(line);

		// Expand any shortcuts.
		if (/{.*?}/.test(line)) {
			let lines = expand_shortcuts(line);
			for (let i = 0, l = lines.length; i < l; i++) {
				// Dupe check line.
				dupecheck(lines[i]);
			}
		} else {
			// No shortcuts, just dupe check.
			dupecheck(line);
		}
	}

	// Create final contents by combining duplicate command chains with
	// all their flag sets.
	for (let commandchain in lookup) {
		if (commandchain && lookup.hasOwnProperty(commandchain)) {
			// Get flags array.
			let flags = lookup[commandchain];
			let fcount = flags.length;

			// No flags...
			if (!fcount) {
				flags = ["--"];
			} else {
				// Join (flatten) all flag sets:
				// [https://www.jstips.co/en/javascript/flattening-multidimensional-arrays-in-javascript/]
				flags = flags.reduce(function(prev, curr) {
					return prev.concat(curr);
				});

				// Sort flags is multiple sets exist.
				if (fcount) {
					flags = flags
						.split("|")
						// [https://stackoverflow.com/a/16481400]
						.sort(function(a, b) {
							return a.localeCompare(b);
						})
						.join("|");
				}
			}

			newlines.push(`${commandchain} ${flags}`);
		}
	}

	// Return generated acdef/config file contents.
	return {
		acdef: header
			.concat(
				newlines.sort(function(a, b) {
					return a.localeCompare(b);
				})
			)
			.join("\n")
			.replace(/\s*$/, ""),
		config: config(settings)
	};
};
