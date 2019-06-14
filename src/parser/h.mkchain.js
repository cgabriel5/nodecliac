"use strict";

// Needed modules.
let { concat } = require("../utils/toolbox.js");

/**
 * Create needed parent command chain(s). For example, if the current
 *     command chain is 'a.b.c' we create the chains: 'a.b' and 'a' if
 *     they do not exist. Kind of like 'mkdir -p'.
 *
 * @param  {string} commandchain - The line's command chain.
 * @param  {string} flags - The line's flag set.
 * @return {undefined} - Nothing is returned.
 */

module.exports = (commandchain, flags, lookup) => {
	// // Normalize command chain. Replace unescaped '/' with '.' dots.
	// commandchain = commandchain.replace(/([^\\]|^)\//g, "$1.");

	// Vars.
	let cparts = [];
	let command = "";
	let command_string = "";
	let command_count = 0;

	// Parse command chain for individual commands.
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
				// Add to lookup.
				let set = new Set();
				// Add highlight set.
				set.__h = new Set();
				// Attach set to chain.
				lookup[command_string] = set;
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

	// Store in lookup table.
	if (!lookup[commandchain]) {
		// Store highlighted set reference.
		let hset = flags.__h;
		// Create new set from old set.
		let set = new Set(flags);
		// Re-attach highlighted set.
		set.__h = hset;
		// Copy original set for expanded chain.
		// [https://stackoverflow.com/a/30626071]
		lookup[commandchain] = set;
	} else {
		// Since chain exists in lookup combine flags.
		concat(lookup[commandchain], flags);
	}
};
