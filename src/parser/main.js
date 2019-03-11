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

// // Needed modules.
// const path = require("path");
// const chalk = require("chalk");
// const { exit } = require("./utils.js");

// Require parser functions.
const config = require("./config.js");
const shortcuts = require("./shortcuts.js");
const dedupe = require("./dedupe.js");
const argparser = require("./argparser.js");
const formatflags = require("./formatflags.js");
const merge = require("./merge.js");

module.exports = (contents, commandname, source) => {
	// Vars - General.
	let line = "";
	let line_count = 0;
	let lookup = {};
	let settings = {};
	let newlines = [];
	// acmap file header.
	let header = [
		`# THIS FILE IS AUTOGENERATED —— DO NOT EDIT FILE DIRECTLY.`,
		`# ${new Date()};${Date.now()}`,
		`# nodecliac definition mapfiles: ~/.nodecliac/defs/\n`
	];

	// Vars - Multi-flag (outer → --flag=[])
	let ismultiline = false;
	let multiline_start;
	let sublines = [];
	// Vars - Multi-flag (inner → --flag=())
	let ismultilineflag = false;
	let multiline_start_flag;
	let sublines_flag;
	let last_multif_flag;

	let prepline = (line, indices, multiflags) => {
		// Remove starting/trailing whitespace?
		line = line.trim();

		// Extract command chain and flags.
		let [, commandchain = "", , flaglist = ""] = line.match(
			/^(.*?)(?:(\s*=?\s*))((-|\[)[\s\S]*?)?$/
		);

		// Work flags...
		let flags = [];
		if (multiflags.length) {
			for (let i = 0, l = multiflags.length; i < l; i++) {
				// Cache current loop item.
				let set = multiflags[i];
				let stype = set.pop();
				let region = set.pop();

				if (stype === 1) {
					// If the last item is ')' then we remove it.
					// If not then then we edit the last item to remove
					// the ')'
					let last_item = (set[set.length - 1] || "").trim();
					if (last_item === ")") {
						set.pop();
					} else {
						set[set.length - 1] = last_item.replace(/\)/, "");
					}

					// Get the flag key.
					let fkey = set[0].trim().replace(/\(\s*$/, "");
					// Store flag before removing possible multi-flag indicator.
					flags.push(fkey);
					// Check if it's a multi-flag.
					if (fkey.endsWith("=*")) {
						fkey = fkey.replace(/=\*/, "=");
					}

					for (let j = 1, ll = set.length; j < ll; j++) {
						// Cache current loop item.
						let value = set[j].trim().replace(/^-\s*/, "");

						flags.push(`${fkey}${value}`);
					}
				} else if (stype === 2) {
					let [, fkey, setter, opts] = set[0]
						.trim()
						.match(/^(-{1,2}.*?)(=\*?)\((.*?)\)$/);
					flags.push(`${fkey}${setter}`);

					// Get individual value options.
					let options = argparser(opts);

					for (let j = 0, ll = options.length; j < ll; j++) {
						// Cache current loop item.
						let option = options[j];
						flags.push(`${fkey}=${option}`);
					}
				} else if (stype === 3) {
					flags.push(set[0].trim());
				}
			}
		}
		// One-liner flags list.
		else {
			// If a list exist then turn into an array.
			if (flaglist) {
				// Parse on unescaped '|' characters:
				// [https://stackoverflow.com/a/25895905]
				// [https://stackoverflow.com/a/12281034]
				flags = flaglist.split(/(?<=[^\\]|^|$)\|/);
			}
		}

		// Format flags list.
		flags = formatflags(flags);

		// Work command chain...

		// Expand any shortcuts.
		if (/{.*?}/.test(commandchain)) {
			let chains = shortcuts(commandchain);
			for (let i = 0, l = chains.length; i < l; i++) {
				// Dupe check line.
				dedupe(chains[i], flags, lookup);
			}
		} else {
			// No shortcuts, just dupe check.
			dedupe(commandchain, flags, lookup);
		}
	};

	// Main loop. Loops over each character in acmap.
	for (let i = 0, l = contents.length; i < l; i++) {
		// Cache current/previous/next chars.
		let char = contents.charAt(i);
		// let pchar = contents.charAt(i - 1);
		let nchar = contents.charAt(i + 1);

		// Check for \r\n newline sequence OR check for regular \n newline char.
		if ((char === "\r" && nchar === "\n") || char === "\n") {
			line_count++;

			// Skip comments/empty lines.
			if (!line.length || /^\s*#/.test(line)) {
				line = "";
				continue;
			}
			// Check if settings line.
			else if (/^\s*@/.test(line)) {
				// Extract setting name/value.
				let [, setting, value] = line.match(
					/^\s*(@[-_:a-zA-Z0-9]{1,})\s*=\s*(.{1,})?$/
				);
				// Store setting/value in settings object.
				settings[setting] = value;

				line = "";
				continue;
			}

			// Append normalized newline char.
			line += "\n";

			// Multi-flag checks:
			// If line ends with '[' (disregarding space)...
			if (/\[\s*$/.test(line)) {
				ismultiline = true;
				// Keep track of where the multi-flag line starts.
				multiline_start = line_count;
			}
			// If line ends with ']' (disregarding space)...
			else if (/\]\s*$/.test(line)) {
				ismultiline = false;
				// Push last line to sublines.
				sublines.push(line);
			}

			if (ismultiline || ismultilineflag) {
				// Remove starting/trailing whitespace?
				let tline = line.trim();

				// Add line to sublines.
				sublines.push(line);

				// Multi-flag checks:
				// If line ends with '(' (disregarding space)...
				if (/\(\s*$/.test(line)) {
					last_multif_flag = [line];
					if (!sublines_flag) {
						sublines_flag = [];
					}
					sublines_flag.push(last_multif_flag);

					ismultilineflag = true;
					// Keep track of where the multi-flag line starts.
					multiline_start_flag = line_count;
				}
				// If line ends with ')' (disregarding space)...
				else if (
					/\)\s*$/.test(line) &&
					// // Cannot be a command-flag.
					!/^\s*-\s*\$\(.*\)\s*$/.test(line) &&
					ismultilineflag
				) {
					ismultilineflag = false;
					// Push last line to sublines.
					last_multif_flag.push(
						line,
						[multiline_start_flag, line_count],
						1
					);
					// Reset flag line number.
					multiline_start_flag = 0;
				}
				// Flag option.
				else if (/^\s*-\s/.test(tline)) {
					// last_multif_flag.push(line.replace(/^\s*-\s*/, ""));
					last_multif_flag.push(line);
				}
				// Flag form: --flag=(val1 val2)
				else if (/^-{1,2}.*?=\*?\(.*?\)$/.test(tline)) {
					last_multif_flag = [line];
					if (!sublines_flag) {
						sublines_flag = [];
					}

					// Push last line to sublines.
					last_multif_flag.push([line_count], 2);

					sublines_flag.push(last_multif_flag);

					// Keep track of where the multi-flag line starts.
					multiline_start_flag = line_count;
				} else if (ismultiline && /^-/.test(tline)) {
					last_multif_flag = [line];
					if (!sublines_flag) {
						sublines_flag = [];
					}

					// Push last line to sublines.
					last_multif_flag.push([line_count], 3);

					sublines_flag.push(last_multif_flag);

					// Keep track of where the multi-flag line starts.
					multiline_start_flag = line_count;
				}

				// Clear line.
				line = "";
			}

			// Prep line if not a multi-flag line.
			if (!ismultiline) {
				let indices = [multiline_start || line_count];

				if (sublines.length) {
					line = sublines.join("");
					indices.push(line_count);
					sublines.length = 0;
				}

				// Split line into commandchain/flags.
				prepline(line, indices, sublines_flag || []);

				// Reset line.
				line = "";
				multiline_start = null;
				last_multif_flag = null;
				sublines_flag = null;
				multiline_start_flag = 0;
			}

			// Increment index to account for the following "\n" char.
			if (char === "\r") i++;
		}
		// All other characters.
		else {
			line += char;
		}
	}

	// Return generated acdef/config file contents.
	return {
		acdef: header
			.concat(
				merge(commandname, lookup, newlines).sort(function(a, b) {
					return a.localeCompare(b);
				})
			)
			.join("\n")
			.replace(/\s*$/, ""),
		config: config(settings, header)
	};
};
