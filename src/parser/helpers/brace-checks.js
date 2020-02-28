"use strict";

const error = require("./error.js");

/**
 * Checks command/flag brace scopes are properly closed.
 *
 * @param  {object} S - State object.
 * @param  {object} N - Node object.
 * @param  {string} check - The check to run.
 * @return {undefined} - Nothing is returned.
 */
module.exports = (S, N, check) => {
	switch (check) {
		// Note: Error if pre-existing command scope exists.
		// Command can't be declared inside a command scope.
		case "pre-existing-cs": {
			let scope = S.scopes.command;
			if (scope) error(S, __filename, 10);

			break;
		}

		// Note: Reset existing scope. If no scope exists
		// the closing brace was wrongly used so error.
		case "reset-scope": {
			let type = N.brace.value === "]" ? "command" : "flag";
			if (S.scopes[type]) S.scopes[type] = null;
			else error(S, __filename, 11);

			break;
		}

		// Note: Error if scope was left unclosed.
		case "post-standing-scope": {
			const { command, flag } = S.scopes;
			const scope = command || flag;

			if (scope) {
				const brackets_start = scope.brackets.start;
				const linestart = S.tables.linestarts[scope.line];

				S.column = brackets_start - linestart + 1; // Point to bracket.
				S.line = scope.line; // Reset to line of unclosed scope.
				error(S, __filename, 12);
			}

			break;
		}

		// Note: Error if pre-existing flag scope exists.
		// Flag option declared out-of-scope.
		case "pre-existing-fs": {
			if (!S.scopes.flag) {
				const linestart = S.tables.linestarts[S.line];

				S.column = S.i - linestart + 1; // Point to bracket.
				error(S, __filename, 13);
			}

			break;
		}
	}
};
