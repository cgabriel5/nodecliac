"use strict";

const error = require("./error.js");

/**
 * Check that command/flag scopes are properly closed.
 *
 * @param  {object} S - The state object.
 * @param  {object} N - The node object.
 * @param  {string} checktype - Name of check to run.
 * @return {undefined} - Nothing is returned.
 */
module.exports = (S, N, checktype) => {
	switch (checktype) {
		// Check whether a pre-existing command scope exists.
		case "pre-existing-cs": {
			let commandscope = S.scopes.command;
			// Note: Can't declare command inside command scope.
			if (commandscope) error(S, __filename, 10);

			break;
		}

		case "reset-scope": {
			// Check brace type. If the scope does not exist then give error.
			let type = N.brace.value === "]" ? "command" : "flag";

			// Note: Scope should exist. If not the close brace was used
			// invalidly. If it does exist clear it.
			if (S.scopes[type]) S.scopes[type] = null;
			// Else, if scope doesn't exist give an error.
			// Note: Error when a ']' doesn't close a scope.
			else error(S, __filename, 11);

			break;
		}

		case "post-standing-scope": {
			const { command, flag } = S.scopes; // Get scopes.

			let commandscope = command || flag; // Use first set scope.

			if (commandscope) {
				// Set line to line number of unclosed command chain.
				S.line = commandscope.line;

				const brackets_start = commandscope.brackets.start;
				const linestart = S.tables.linestarts[S.line];

				// Note: Add 1 for 0 base indexing (column starts at 1).
				S.column = brackets_start - linestart + 1; // Point column to bracket.

				error(S, __filename, 12); // Note: If scope is left unclosed, error.
			} else return; // If no scope set return and error.

			break;
		}

		// Check whether a pre-existing flag scope exists.
		case "pre-existing-fs": {
			if (!S.scopes.flag) {
				const linestart = S.tables.linestarts[S.line];

				// Note: Add 1 for 0 base indexing (column starts at 1).
				S.column = S.i - linestart + 1; // Point column to bracket.

				error(S, __filename, 13); // Note: Flag option declared out of scope.
			}

			break;
		}
	}
};
