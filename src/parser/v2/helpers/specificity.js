"use strict";

// Get needed modules.
let issue = require("./issue.js");

/**
 * Check that line specificity is allowed.
 *
 * @param  {object} STATE - Main loop state object.
 * @param  {string} line_type - The line's line type.
 * @return {string} - The line's type.
 */
module.exports = (STATE, line_type) => {
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

	// Get line specificity and store value.
	let line_specificity = SPECIFICITIES[line_type] || 0;
	let scopes = STATE.scopes; // Get scopes.

	// However, if we are in a scope then the scope's specificity
	// trumps the line specificity.
	let state_specificity = scopes.flag
		? SPECIFICITIES.flag
		: scopes.command
		? SPECIFICITIES.command
		: STATE.specificity;

	// Note: Check whether specificity hierarchy is allowed.
	if (state_specificity && state_specificity < line_specificity) {
		// Note: Line specificity is incorrect so give error.
		issue.error(STATE, 12);
	}
	// Set state specificity.
	STATE.specificity = line_specificity;
};
