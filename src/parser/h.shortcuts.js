"use strict";

/**
 * Expand shortcuts. For example, command.{cmd1|cmd2} will expand
 *     to command.cmd1 and command.cmd2.
 *
 * @param  {string} commandchain - The commandchain with shortcuts to
 *     expand.
 * @return {array} - Array containing the expand lines.
 */
module.exports = commandchain => {
	let flines = [];

	if (/{.*?}/.test(commandchain)) {
		let shortcuts;

		// Place hold shortcuts.
		commandchain = commandchain.replace(/{.*?}/, function(match) {
			// Remove syntax decorations + whitespace.
			shortcuts = match.replace(/^{|}$/gm, "").split("|");

			for (let i = 0, l = shortcuts.length; i < l; i++) {
				// Cache current loop item.
				let sc = shortcuts[i];

				flines.push(commandchain.replace(/{.*?}/, sc));
			}

			// Remove shortcut from command by returning anonymous placeholder.
			return "--PL";
		});
	}

	// Use function recursion to completely expand all shortcuts.
	let recursion = [];
	if (/{.*?}/.test(flines[0])) {
		for (let i = 0, l = flines.length; i < l; i++) {
			// Cache current loop item.
			let commandchain = flines[i];

			// Since using recursion function accessible as 'module.exports'.
			recursion = recursion.concat(module.exports(commandchain, true));
		}
	}
	if (recursion.length) {
		return recursion;
	}

	return flines;
};
