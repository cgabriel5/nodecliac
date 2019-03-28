/**
 * Run post operations on command chain and its respective flag set.
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
	let r = new RegExp(`^(${commandname}|[-_a-zA-Z0-9]+)`);

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

			// Finally, add to newlines array.
			newlines.push(row);
		}
	}

	return newlines;
};
