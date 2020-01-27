"use strict";

/**
 * Check that command/flag scopes are properly closed.
 *
 * @param  {object} STATE - The STATE object.
 * @param  {object} NODE - The NODE object.
 * @param  {string} checktype - Name of check to run.
 * @return {undefined} - Nothing is returned.
 */
module.exports = (STATE, NODE, checktype) => {
	let issue = STATE.utils.functions.loop.issue; // Utility functions and constants.

	switch (checktype) {
		// Check whether a pre-existing command scope exists.
		case "pre-existing-cs": {
			let commandscope = STATE.scopes.command;
			// Note: Can't declare command inside command scope.
			if (commandscope) error(STATE, __filename, 10);

			break;
		}

		case "reset-scope": {
			// Check brace type. If the scope does not exist then give error.
			let type = NODE.brace.value === "]" ? "command" : "flag";

			// Note: Scope should exist. If not the close brace was used
			// invalidly. If it does exist clear it.
			if (STATE.scopes[type]) STATE.scopes[type] = null;
			// Else, if scope doesn't exist give an error.
			// Note: Error when a ']' doesn't close a scope.
			else error(STATE, __filename, 11);

			break;
		}

		case "post-standing-scope": {
			const { command, flag } = STATE.scopes; // Get scopes.

			let commandscope = command || flag; // Use first set scope.

			if (commandscope) {
				// Set line to line number of unclosed command chain.
				STATE.line = commandscope.line;

				const brackets_start = commandscope.brackets.start;
				const linestart = STATE.tables.linestarts[STATE.line];

				// Note: Add 1 for 0 base indexing (column starts at 1).
				STATE.column = brackets_start - linestart + 1; // Point column to bracket.

				error(STATE, __filename, 12); // Note: If scope is left unclosed, error.
			} else return; // If no scope set return and error.

			break;
		}

		// Check whether a pre-existing flag scope exists.
		case "pre-existing-fs": {
			if (!STATE.scopes.flag) {
				const linestart = STATE.tables.linestarts[STATE.line];

				// Note: Add 1 for 0 base indexing (column starts at 1).
				STATE.column = STATE.i - linestart + 1; // Point column to bracket.

				error(STATE, __filename, 13); // Note: Flag option declared out of scope.
			}

			break;
		}
	}
};
