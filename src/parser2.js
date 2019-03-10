"use strict";

// Parser:
// - comments
// 	- single line
// 	- trailing-ending comments
// - @settings
// - command chains
// 	- shortcuts
// - long-form flags
// 	- command-flags
// 	- flags options list

// - balanced braces
// - validate characters for cchains
// - account for line numbers/errors

// // Needed modules.
// const path = require("path");
// const chalk = require("chalk");
// const { exit } = require("./utils.js");

module.exports = (contents, commandname, source) => {
	// Vars.
	let line = "";
	let lines = [];
	let ismultiline = false;
	let multiline_start;
	let sublines = [];
	let settings = {};
	let line_count = 0;

	let prepline = (line, indices) => {
		// Remove starting/trailing whitespace?
		line = line.trim();

		// Ignore comments/empty lines.
		if (line.charAt(0) === "#" || !line) return;

		// Check if settings line.
		if (/^@/.test(line)) {
			// Extract setting name/value.
			let [, setting, value] = line.match(
				/@([-_:a-zA-Z0-9]{1,})\s*=\s*(.{1,})?$/
			);
			// Store setting/value in settings object.
			settings[setting] = value;

			// Return to not store line.
			return;
		}

		// Extract command chain and flags.
		let [, commandchain = "", , flags = ""] = line.match(
			/^(.*?)(?:(\s*=?\s*))((-|\[)[\s\S]*?)?$/
		);

		// Log extracted line.
		lines.push([commandchain, flags, indices]);
	};

	// Main loop. Loops over each character in acmap.
	for (let i = 0, l = contents.length; i < l; i++) {
		// Cache current/previous/next chars.
		let char = contents.charAt(i);
		let pchar = contents.charAt(i - 1);
		let nchar = contents.charAt(i + 1);

		// Check for \r\n newline sequence OR check for regular \n newline char.
		if ((char === "\r" && nchar === "\n") || char === "\n") {
			line_count++;

			// Append normalized newline char.
			line += "\n";

			// Multi-flag checks:
			// If line ends with '[' (disregarding space)...
			if (/\[\s*$/.test(line)) {
				ismultiline = true;
				// Keep track of where the multiflag line starts.
				multiline_start = line_count;
			}
			// If line ends with ']' (disregarding space)...
			else if (/\]\s*$/.test(line)) {
				ismultiline = false;
				// Push last line to sublines.
				sublines.push(line);
			}

			if (ismultiline) {
				// Remove starting/trailing whitespace?
				let tline = line.trim();

				// Ignore comments/empty lines.
				if (tline && tline.charAt(0) !== "#") {
					// Add line to sublines.
					sublines.push(line);
				}

				line = "";
			}
			// Prep line if not a multi-flag line.
			else if (!ismultiline) {
				let indices = [multiline_start || line_count];

				if (sublines.length) {
					line = sublines.join("");
					indices.push(line_count);
					sublines.length = 0;
				}

				// Split line into commandchain/flags.
				prepline(line, indices);

				// Reset line.
				line = "";
				multiline_start = null;
			}

			// Increment index to account for the following "\n" char.
			if (char === "\r") i++;
		}
		// All other characters.
		else {
			line += char;
		}
	}

	console.log(settings);
	console.log(lines);
	// console.log(lines.length);
	// for (let i = 0, l = lines.length; i < l; i++) {
	// 	// Cache current loop item.
	// 	let line = lines[i];
	// 	console.log(line);
	// }
};
