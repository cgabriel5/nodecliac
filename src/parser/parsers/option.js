"use strict";

const node = require("../helpers/nodes.js");
const add = require("../helpers/tree-add.js");
const error = require("../helpers/error.js");
const rollback = require("../helpers/rollback.js");
const validate = require("../helpers/validate-value.js");
const bracechecks = require("../helpers/brace-checks.js");
const { r_nl, r_space, r_quote } = require("../helpers/patterns.js");

/**
 * Flag option parser.
 *
 * ---------- Parsing Breakdown ------------------------------------------------
 * - value
 *  |     ^-EOL-Whitespace-Boundary 2
 *  ^-Whitespace-Boundary 1
 * ^-Bullet
 *  ^-Value
 * -----------------------------------------------------------------------------
 *
 * @param  {object} S - Main loop state object.
 * @return {object} - Object containing parsed information.
 */
module.exports = S => {
	let { line, l, text } = S;
	let end_comsuming;
	let state = "bullet";
	let N = node(S, "OPTION");

	// Note: If a flag scope doesn't exist, error as it needs to.
	bracechecks(S, null, "pre-existing-fs");

	// Loop over string.
	for (; S.i < l; S.i++) {
		let char = text.charAt(S.i); // Cache current loop char.

		// End loop on a newline char.
		if (r_nl.test(char)) {
			N.endpoint = --S.i; // Rollback (run '\n' parser next).

			break;
		}

		S.column++; // Increment column position.

		switch (state) {
			case "bullet":
				// Store index positions.
				N.bullet.start = S.i;
				N.bullet.end = S.i;
				N.bullet.value = char; // Start building string.

				state = "spacer"; // Reset parsing state.

				break;

			case "spacer":
				// Note: A whitespace character must follow bullet, else error.
				if (!r_space.test(char)) error(S, __filename);

				state = "wsb-prevalue"; // Reset parsing state.

				break;

			case "wsb-prevalue":
				// Note: Allow whitespace until first non-whitespace char is hit.
				if (!r_space.test(char)) {
					rollback(S); // Rollback loop index.

					state = "value";
				}

				break;

			case "value":
				{
					// Value:
					// - Command-flags  => $("cat")
					// - Strings        => "value"
					// - Escaped-values => val\ ue

					let pchar = text.charAt(S.i - 1); // Previous char.

					// Determine value type.
					if (!N.value.value) {
						let type = "escaped"; // Set default.

						if (char === "$") type = "command-flag";
						else if (char === "(") type = "list";
						else if (r_quote.test(char)) type = "quoted";

						N.value.type = type; // Set type.

						// Store index positions.
						N.value.start = S.i;
						N.value.end = S.i;
						N.value.value = char; // Start building string.
					} else {
						// If flag is set and characters can still be consumed
						// then there is a syntax error. For example, string
						// may be improperly quoted/escaped so give error.
						if (end_comsuming) error(S, __filename);

						// Get string type.
						let stype = N.value.type;

						// Escaped string logic.
						if (stype === "escaped") {
							if (r_space.test(char) && pchar !== "\\") {
								end_comsuming = true; // Set flag.
							}

							// Quoted string logic.
						} else if (stype === "quoted") {
							let value_fchar = N.value.value.charAt(0);
							if (char === value_fchar && pchar !== "\\") {
								end_comsuming = true; // Set flag.
							}
						}

						// Store index positions.
						N.value.end = S.i;
						N.value.value += char; // Continue building string.
					}
				}

				break;
		}
	}

	validate(S, N); // Validate extracted variable value.
	add(S, N); // Add node to tree.
};
