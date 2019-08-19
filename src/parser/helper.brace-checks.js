"use strict";

// Get needed modules.
let issue = require("./helper.issue.js");

/**
 * Check that command/flag scopes are properly closed.
 *
 * @param  {object} NODE - The NODE object.
 * @param  {object} STATE - The STATE object.
 * @param  {string} checktype - The check to run.
 * @return {undefined} - Nothing is returned.
 */
module.exports = (STATE, NODE, checktype) => {
	switch (checktype) {
		// Check whether a pre-existing command scope exists.
		case "pre-existing-cs": {
			let commandscope = STATE.scopes.command;
			if (commandscope) {
				// Change line to line number of unclosed command chain.
				STATE.line = commandscope.line;

				// Point column to the bracket.
				STATE.column =
					commandscope.brackets.start -
					STATE.DB.linestarts[STATE.line] +
					// Note: Add 1 to account for 0 base indexing (column starts at 1).
					1;

				// Note: Cannot declare command inside command scope.
				issue.error(STATE, 10);
			}
			break;
		}

		case "reset-scope": {
			// Check brace type. If the scope does not exist then give error.
			let type = NODE.brace.value === "]" ? "command" : "flag";

			// Note: Scope should exist. Otherwise the closing brace is being used
			// invalidly. Clear scope if it does exist.
			let commandscope = STATE.scopes[type];
			if (commandscope) {
				STATE.scopes[type] = null;

				// Else, if scope does not exist give an error.
			} else {
				// Note: Give error when a ']' does not close a scope.
				issue.error(STATE, 11);
			}

			break;
		}

		case "post-standing-scope": {
			// Get first set scope.
			let type = STATE.scopes.command
				? "command"
				: STATE.scopes.flag
				? "flag"
				: null;

			// If the scope does not exist then give error.
			if (!type) {
				return;
			}

			let commandscope = STATE.scopes[type];
			if (commandscope) {
				// Change line to line number of unclosed command chain.
				STATE.line = commandscope.line;

				// Point column to the bracket.
				STATE.column =
					commandscope.brackets.start -
					STATE.DB.linestarts[STATE.line] +
					// Note: Add 1 to account for 0 base indexing (column starts at 1).
					1;

				// Note: If a scope is left unclosed give error.
				issue.error(STATE, 12);
			}

			break;
		}

		// Check whether a pre-existing flag scope exists.
		case "pre-existing-fs": {
			let flagscope = STATE.scopes.flag;
			if (!flagscope) {
				// Point column to the bracket.
				STATE.column =
					STATE.i -
					STATE.DB.linestarts[STATE.line] +
					// Note: Add 1 to account for 0 base indexing (column starts at 1).
					1;

				// Note: Cannot declare flag option out of scope.
				issue.error(STATE, 13);
			}
			break;
		}
	}
};
