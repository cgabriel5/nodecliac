"use strict";

const error = require("./error.js");

/**
 * Validate line specificity.
 *
 * @param  {object} S - State object.
 * @param  {string} line_type - The line's line type.
 * @return {undefined} - Nothing is returned.
 */
module.exports = (S, line_type, parserfile) => {
	// Note: [Hierarchy lookup table] The higher the number the higher its
	// precedence. Therefore: command > flag > option. Variables, settings,
	// and command chains have the same precedence as they are same-level
	// defined (cannot be nested). Comments can be placed anywhere so
	// they don't have a listed precedence.
	const SPECF = {
		setting: 3,
		variable: 3,
		command: 3,
		flag: 2,
		option: 1,
		comment: 0
	};

	let line_specf = SPECF[line_type] || 0;
	let { flag: fs, command: cs } = S.scopes;

	// Note: When in a scope, scope's specificity trumps line's specificity.
	let state_specf = fs ? SPECF.flag : cs ? SPECF.command : S.specf;

	// Error when specificity is invalid.
	if (state_specf && state_specf < line_specf) error(S, parserfile, 12);
	S.specf = line_specf;
};
