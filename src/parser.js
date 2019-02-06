"use strict";

module.exports = contents => {
module.exports = (contents, source) => {
	// Vars.
	let newlines = [
		// acmap file header.
		`# THIS FILE IS AUTOGENERATED —— DO NOT EDIT FILE DIRECTLY.`,
		`# nodecliac definition mapfiles: ~/.nodecliac/defs/\n\n`
	];
	let placeholders = [];
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
			/^\s*-{1,2}[a-z][a-z0-9-]*\s*=\s*\([\s\S]*?\)/gim,
			function(match) {
				// Format options.

				// [https://stackoverflow.com/a/18515993]
				let lb_regexp = /\r?\n/;

				// If the match does not have line breaks leave it alone. For
				// example, "--Wno-strict-overflow=(2 5)" normalize it.
				if (!lb_regexp.test(match)) {
					let eq_index = match.indexOf("=");
					let flag = match.substring(0, eq_index);
					let options = match.substring(
						eq_index + 2,
						match.length - 1
					);

					match = `${flag}=(\n${options.replace(/\s{1,}/g, "\n")}\n)`;
				}

				// Get flag name.
				let [, indentation, flag, options] = match.match(
					/^(\s*)(-{1,2}[a-z][a-z0-9-]*)\s*=\s*\(([\s\S]*?)\)/im
				);

				// Turn options list into an array.
				options = options.trim().split(lb_regexp);

				// Remove duplicate option values.
				let options_list = [];
				// Loop over options.
				for (let i = 0, l = options.length; i < l; i++) {
					// Cache current loop item.
					let option = options[i].trim();

					// Remove flag multi-line option/value marker ('- ').
					option = option.replace(/^-\s*/, "");

					// Filter out duplicate option values.
					if (-~options_list.indexOf(option)) {
						continue;
					}
					options_list.push(option);
				}

				// Sort the options and return.
				return options_list
					.sort(function(a, b) {
						return a.localeCompare(b);
					})
					.map(function(option) {
						return `${indentation}${flag}=${option.trim()}`;
					})
					.join("\n");
			}
		));
	};

	/**
	 * Fill-in placeholded long-form flags with collapsed single line
	 *     containing the formated flags.
	 *
	 * @param  {string} contents - The line to with possible placeholders.
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

	// Exit if file is empty.
	if (!contents.trim().length) {
		exit([`Action aborted. ${chalk.bold(source)} is empty.`]);
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
		// Place hold long-form flags.
		.replace(/\[[\s\S]*?\]/g, function(match) {
			// Process and store flag placeholders.
			placeholders.push(unexpand_mf_options(match));
			// Return placeholder marker.
			return `--LFFPH#${placeholders.length}`;
		});

	// Go line by line:
	let lines = contents.split("\n");
	for (let i = 0, l = lines.length; i < l; i++) {
		// Cache current loop item.
		let line = lines[i].trim();

		// Check whether flags were provided.
		if (!line.includes(" --")) {
			line += " --";
		}
		// Remove all equal-sign pointers.
		line = line.replace(/\s{1,}=\s*/g, " ");
		// Fill back in long form flag placeholders.
		line = fillin_ph_lf_flags(line);

		// Expand any shortcuts.
		if (/{.*?}/.test(line)) {
			let lines = expand_shortcuts(line);
			for (let i = 0, l = lines.length; i < l; i++) {
				newlines.push(lines[i]);
			}
		} else {
			// Else, simply add the line.
			newlines.push(line);
		}
	}

	return newlines.join("\n");
};
