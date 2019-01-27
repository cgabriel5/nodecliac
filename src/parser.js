"use strict";

module.exports = contents => {
	// let maincommand;
	let newlines = [];
	let placeholders = [];

	let expand_shortcuts = function(line) {
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

	// Un-expand multi-line flag options.
	let unexpand_mf_options = function(contents) {
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

				options = options.trim().split(lb_regexp);

				// Remove duplicate option values.
				let options_list = [];
				// Loop over options.
				for (let i = 0, l = options.length; i < l; i++) {
					// Cache current loop item.
					let option = options[i].trim();

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
	// Fill-in place hold long-form flags.
	let fillin_ph_lf_flags = function(contents) {
		// Place hold long-form flags.
		let r = /--LFFPH#\d{1,}/g;
		return (contents = contents.replace(r, function(match) {
			// Get flags from placeholders array.
			match = placeholders[match.match(/\d+/g) * 1 - 1];

			// Format flags.

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
			let t3lkup = lists.type3.lookup;

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
						let value = flag.substring(eq_index + 1);

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

	// Initial content modifications.
	contents = contents
		// Remove comments.
		.replace(/^\s*#.*$/gm, "")
		// Remove line breaks.
		.replace(/\n{1,}/gm, "\n")
		// // Get main command (line starting with "@" sign).
		// .replace(/^@.*?$/m, function(match) {
		// 	// Store command.
		// 	maincommand = `| ${match.replace(/^@*/g, "@")}.acmap |`;
		// 	return "";
		// })
		// Place hold long-form flags.
		.replace(/\[[\s\S]*?\]/g, function(match) {
			// Store contents.
			placeholders.push(match);
			// Return placeholder marker.
			return `--LFFPH#${placeholders.length}`;
		})
		.trim();

	let header_decor_length = 47;
	// Add header.
	newlines.push(
		// `# ${"—".repeat(header_decor_length)}`,
		// `# —— Autogenerated File — Don't Edit Directly! ——`
		// `# ${"—".repeat(header_decor_length - maincommand.length)}${maincommand}`
		`# THIS FILE IS AUTOGENERATED. DO NOT EDIT FILE DIRECTLY.`,
		`# nodecliac definition mapfiles: ~/.nodecliac/maps/\n\n`
	);

	// Process flag placeholders.
	if (placeholders.length) {
		for (let i = 0, l = placeholders.length; i < l; i++) {
			// Cache current loop item.
			let placeholder = placeholders[i];
			// console.log(placeholder);
			// console.log(unexpand_mf_options(placeholder));
			placeholders[i] = unexpand_mf_options(placeholder);
		}
	}

	// Go line by line:
	let lines = contents.split("\n");
	for (let i = 0, l = lines.length; i < l; i++) {
		// Cache current loop item.
		let line = lines[i].trim();

		// Skip comments and empty lines.
		if (!line.length || line.startsWith("#")) {
			continue;
		}

		// Check whether flags were provided.
		if (!line.includes(" --")) {
			line += " --";
		}

		// Remove all equal-sign pointers.
		line = line.replace(/\s{1,}=\s*/g, " ");

		line = fillin_ph_lf_flags(line);

		// Check if line contains shortcuts to expand.
		if (/{.*?}/.test(line)) {
			let lines = expand_shortcuts(line);

			for (let i = 0, l = lines.length; i < l; i++) {
				// Expand shortcuts.
				newlines.push(lines[i]);
			}
		} else {
			newlines.push(line);
		}
	}

	return newlines.join("\n");

	// return {
	// 	acmap: newlines.join("\n")
	// 	// maincommand: maincommand.replace(/(\||@|\.acmap|\s*)/g, "")
	// };
};
