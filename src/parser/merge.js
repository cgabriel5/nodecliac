// Require needed modules.
const unique = require("./unique.js");

/**
 * Create final contents by combining duplicate command chains with all
 *     their flag sets.
 *
 * @param  {string} commandname - The main command name.
 * @param  {object} lookup - Lookup table containing single chains to their
 *                         	 potentially multiple sets of flags.
 * @param  {array} newlines - The array containing merged lines.
 * @return {array} - The newlines array.
 */
module.exports = (commandname, lookup, newlines) => {
	// Vars.
	let has_root = false;
	// RegExp to match main command/first command in chain to remove.
	let r = new RegExp(`^(${commandname}|[-_a-zA-Z0-9]+)`, "gm");

	// Loop over command chain lookup table.
	for (let commandchain in lookup) {
		if (commandchain && lookup.hasOwnProperty(commandchain)) {
			// Get flags array.
			let flags = lookup[commandchain];
			let fcount = flags.length;

			if (fcount) {
				// Join (flatten) all flag sets:
				// [https://www.jstips.co/en/javascript/flattening-multidimensional-arrays-in-javascript/]
				flags = flags.reduce(function(prev, curr) {
					return prev.concat(curr);
				});

				// Dedupe and sort flags if multiple sets exist.
				flags = unique(flags, "alpha").join("|");
			} else {
				flags = "--";
			}

			// Remove the main command from the command chain. However,
			// when the command name is not the main command in (i.e.
			// when running on a test file) just remove the first command
			// name in the chain.
			let row = `${commandchain.replace(r, "")} ${flags}`;

			// Remove multiple ' --' command chains. This will happen for
			// test files with multiple main commands.
			if (row === " --" && !has_root) {
				has_root = true;
			} else if (row === " --" && has_root) {
				continue;
			}

			// Finally add to newlines array.
			newlines.push(row);
		}
	}

	return newlines;
};
