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
module.exports = lk_size => {
	// Get globals.
	let h = global.$app.get("highlighter");
	let lookup = global.$app.get("lookup");
	let commandname = global.$app.get("commandname");
	let highlight = global.$app.get("highlight");
	let header = global.$app.get("header");

	// Vars.
	let has_root = false;
	// RegExp to match main command/first command in chain to remove.
	let r = new RegExp(`^(${commandname}|[-_a-zA-Z0-9]+)`);
	// Store lines.
	let lines = [];
	let hlines = [];

	// RegExp patter for multi-flag indicator.
	let r_mf = /=\*$/;

	// If lines array is empty give warning and exit.
	if (!lk_size) {
		exit(
			[`[${chalk.bold.yellow("warn")}] File is void of definitions.`],
			false
		);

		// Return an empty string.
		return "";
	}

	/**
	 * Sort function.
	 *
	 * @param  {string} a - Item a.
	 * @param  {string} b - Item b.
	 * @return {number} - The sort number result.
	 */
	let sorter = (a, b) => {
		// Get un-highlighted flag items only.
		a = a[0];
		b = b[0];

		// Give multi-flags higher sorting precedence.
		// [https://stackoverflow.com/a/9604891]
		// [https://stackoverflow.com/a/24292023]
		// [http://www.javascripttutorial.net/javascript-array-sort/]
		return ~~b.endsWith("=*") - ~~a.endsWith("=*") || a.localeCompare(b);
	};

	// Loop over command chain lookup table.
	for (let chain in lookup) {
		if (chain && lookup.hasOwnProperty(chain)) {
			// Get flags array.
			let flags = lookup[chain];
			// Get highlighted flags.
			let hflags = lookup[chain].__h;
			// Get set length (size).
			let fcount = flags.size;

			// Use zip method to only sort 1 array: [https://stackoverflow.com/a/6418539]
			// [https://stackoverflow.com/a/13960306], [https://stackoverflow.com/q/11499268]

			// If set contains flags sort its values.
			if (fcount) {
				// Convert set to an array, sort, then turn to string.
				// [https://stackoverflow.com/a/47243199], [https://stackoverflow.com/a/21194765]
				flags = [...flags];
				hflags = [...hflags];
				let zip = []; // The zip array.

				// Use 'zip' to only sort main un-highlighted flags array.
				for (let i = 0, l = flags.length; i < l; i++) {
					// Store values in zip array.
					zip.push([flags[i], hflags[i]]);
				}

				// Sort array using the un-highlighted flags array.
				zip.sort(sorter);

				// unzip
				for (let i = 0, l = zip.length; i < l; i++) {
					let z = zip[i];
					flags[i] = z[0];
					hflags[i] = z[1];
				}

				// Joins arrays.
				flags = flags.join("|");
				hflags = hflags.join("|");
			}
			// If no flags reset to empty flag indicator.
			else {
				flags = "--";
				hflags = "--";
			}

			// Remove the main command from the command chain. However,
			// when the command name is not the main command in (i.e.
			// when running on a test file) just remove the first command
			// name in the chain.
			let row = `${chain.replace(r, "")} ${flags}`;
			let hrow = `${h(chain.replace(r, ""), "command")} ${hflags}`;

			// Remove multiple ' --' command chains. This will happen for
			// test files with multiple main commands.
			if (row === " --" && !has_root) {
				has_root = true;
			} else if (row === " --" && has_root) {
				continue;
			}

			// Finally, add to line.
			lines.push(row);
			hlines.push(hrow);
		}
	}

	/**
	 * Sort function.
	 *
	 * @param  {string} a - Item a.
	 * @param  {string} b - Item b.
	 * @return {number} - The sort number result.
	 */
	let aplhasort = (a, b) => {
		return a.localeCompare(b);
	};

	// Generate un-highlighted and highlighted acmaps.
	let content = [header]
		.concat(lines.sort(aplhasort))
		.join("\n")
		.replace(/\s*$/, "");
	let hcontent = [h(header, "comment")]
		.concat(hlines.sort(aplhasort))
		.join("\n")
		.replace(/\s*$/, "");

	return {
		content,
		hcontent,
		print: highlight ? hcontent : content
	};
};
