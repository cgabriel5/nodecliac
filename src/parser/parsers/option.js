"use strict";

const node = require("../helpers/nodes.js");
const add = require("../helpers/tree-add.js");
const error = require("../helpers/error.js");
const rollback = require("../helpers/rollback.js");
const validate = require("../helpers/validate-value.js");
const bracechecks = require("../helpers/brace-checks.js");
const { r_nl, r_space, r_quote } = require("../helpers/patterns.js");

/**
 * ----------------------------------------------------------- Parsing Breakdown
 * - value
 *  |     ^-EOL-Whitespace-Boundary 2
 *  ^-Whitespace-Boundary 1
 * ^-Bullet
 *  ^-Value
 * -----------------------------------------------------------------------------
 *
 * @param  {object} S - State object.
 * @return {undefined} - Nothing is returned.
 */
module.exports = S => {
	let { l, text } = S;
	let end_comsuming;
	let state = "bullet";
	let N = node(S, "OPTION");

	// Note: If a flag scope doesn't exist, error as it needs to.
	bracechecks(S, null, "pre-existing-fs");

	for (; S.i < l; S.i++, S.column++) {
		let char = text.charAt(S.i);

		// Stop on a newline char.
		if (r_nl.test(char)) {
			N.endpoint = rollback(S) && S.i;

			break;
		}

		switch (state) {
			case "bullet":
				N.bullet.start = S.i;
				N.bullet.end = S.i;
				N.bullet.value = char;
				state = "spacer";

				break;

			case "spacer":
				// A whitespace character must follow bullet, else error.
				if (!r_space.test(char)) error(S, __filename);
				state = "wsb-prevalue";

				break;

			case "wsb-prevalue":
				// Allow whitespace until first non-whitespace char is hit.
				if (!r_space.test(char)) {
					rollback(S);
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

						N.value.type = type;
						N.value.start = S.i;
						N.value.end = S.i;
						N.value.value = char;
					} else {
						// If flag is set and characters can still be consumed
						// then there is a syntax error. For example, string
						// may be improperly quoted/escaped so give error.
						if (end_comsuming) error(S, __filename);

						let stype = N.value.type; // Get string type.

						// Escaped string logic.
						if (stype === "escaped") {
							if (r_space.test(char) && pchar !== "\\") {
								end_comsuming = true;
							}
						}
						// Quoted string logic.
						else if (stype === "quoted") {
							let value_fchar = N.value.value.charAt(0);
							if (char === value_fchar && pchar !== "\\") {
								end_comsuming = true;
							}
						}
						N.value.end = S.i;
						N.value.value += char;
					}
				}

				break;
		}
	}

	validate(S, N);
	add(S, N);
};
