"use strict";

const error = require("./error.js");

/**
 * Checks if line specificity is allowed.
 *
 * @param  {object} S - Main loop state object.
 * @param  {string} line_type - The line's line type.
 * @return {string} - The line's type.
 */
module.exports = (S, line_type) => {
	// Note: [Hierarchy lookup table] The higher the number the higher its
	// precedence, therefore: command > flag > option. Variables, settings,
	// and command chains have the same precedence as they are same-level
	// defined (cannot be nested). Comments can be placed anywhere so
	// they don't have a listed precedence.
	const SPECIFICITIES = {
		setting: 3,
		variable: 3,
		command: 3,
		flag: 2,
		option: 1,
		comment: 0
	};

	let line_specf = SPECIFICITIES[line_type] || 0; // Get line specificity.
	let scopes = S.scopes; // Get scopes.

	// However, if we are in a scope then the scope's specificity
	// trumps the line specificity.
	let state_specf = scopes.flag
		? SPECIFICITIES.flag
		: scopes.command
		? SPECIFICITIES.command
		: S.specificity;

	// Note: Check whether specificity hierarchy is allowed, else error.
	if (state_specf && state_specf < line_specf) error(S, __filename, 12);
	S.specificity = line_specf; // Set state specificity.
};
