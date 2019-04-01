"use strict";

// Needed modules.
const path = require("path");
const chalk = require("chalk");
const { fileinfo, exit, paths } = require("../utils.js");

/**
 * Run post operations on command chain and its respective flag set.
 *
 * @param  {string} commandname - The main command name.
 * @param  {object} lookup - Lookup table containing single chains to their
 *                         	 potentially multiple sets of flags.
 * @param  {number} lk_size - The lookup object size.
 * @param  {array} header - The final file's header information.
 * @return {array} - The new lines array.
 */
module.exports = (commandname, lookup, lk_size, header) => {
	// Vars.
	let has_root = false;
	// RegExp to match main command/first command in chain to remove.
	let r = new RegExp(`^(${commandname}|[-_a-zA-Z0-9]+)`);
	// Store lines.
	let lines = [];

	// If lines array is empty give warning and exit.
	if (!lk_size) {
		exit(
			[`[${chalk.bold.yellow("warn")}] File is void of definitions.`],
			false
		);

		// Return an empty string.
		return "";
	}

	// Loop over command chain lookup table.
	for (let chain in lookup) {
		if (chain && lookup.hasOwnProperty(chain)) {
			// Get flags array.
			let flags = lookup[chain];
			// Get set length (size).
			let fcount = flags.size;

			// If set contains flags sort its values.
			if (fcount) {
				// Convert set to an array, sort, then turn to string.
				// [https://stackoverflow.com/a/47243199]
				flags = Array.from(flags)
					.sort(function(a, b) {
						return a.localeCompare(b);
					})
					.join("|");
			}
			// If no flags reset to empty flag indicator.
			else {
				flags = "--";
			}

			// Remove the main command from the command chain. However,
			// when the command name is not the main command in (i.e.
			// when running on a test file) just remove the first command
			// name in the chain.
			let row = `${chain.replace(r, "")} ${flags}`;

			// Remove multiple ' --' command chains. This will happen for
			// test files with multiple main commands.
			if (row === " --" && !has_root) {
				has_root = true;
			} else if (row === " --" && has_root) {
				continue;
			}

			// Finally, add to lines array.
			lines.push(row);
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
