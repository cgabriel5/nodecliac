"use strict";

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
 * @param  {object} STATE - Main loop state object.
 * @return {object} - Object containing parsed information.
 */
module.exports = STATE => {
	let { line, l, string, utils } = STATE; // Loop state vars.
	// Utility functions and constants.
	let { functions: F, constants: C } = utils;
	let { r_nl, r_whitespace, r_quote } = C.regexp;
	let { issue, rollback, validate, bracechecks } = F.loop;
	let { add } = F.tree;

	// Note: If a flag scope doesn't exist, error as it needs to.
	bracechecks(STATE, null, "pre-existing-fs");

	// Parsing vars.
	let state = "bullet"; // Initial parsing state.
	let end_comsuming;
	let NODE = {
		node: "OPTION",
		bullet: { start: null, end: null, value: null },
		value: { start: null, end: null, value: null, type: null },
		line,
		startpoint: STATE.i,
		endpoint: null // Index where parsing ended.
	};

	// Loop over string.
	for (; STATE.i < l; STATE.i++) {
		let char = string.charAt(STATE.i); // Cache current loop char.

		// End loop on a newline char.
		if (r_nl.test(char)) {
			// Rollback to run newline char code block next iteration.
			NODE.endpoint = --STATE.i; // Store newline index.

			break;
		}

		STATE.column++; // Increment column position.

		switch (state) {
			case "bullet":
				// Store index positions.
				NODE.bullet.start = STATE.i;
				NODE.bullet.end = STATE.i;
				NODE.bullet.value = char; // Start building string.

				state = "spacer"; // Reset parsing state.

				break;

			case "spacer":
				// Note: A whitespace character must follow bullet, else error.
				if (!r_whitespace.test(char)) error(STATE, __filename);

				state = "wsb-prevalue"; // Reset parsing state.

				break;

			case "wsb-prevalue":
				// Note: Allow whitespace until first non-whitespace char is hit.
				if (!r_whitespace.test(char)) {
					rollback(STATE); // Rollback loop index.

					state = "value";
				}

				break;

			case "value":
				{
					// Value:
					// - Command-flags  => $("cat")
					// - Strings        => "value"
					// - Escaped-values => val\ ue

					let pchar = string.charAt(STATE.i - 1); // Previous char.

					// Determine value type.
					if (!NODE.value.value) {
						let type = "escaped"; // Set default.

						if (char === "$") type = "command-flag";
						else if (char === "(") type = "list";
						else if (r_quote.test(char)) type = "quoted";

						NODE.value.type = type; // Set type.

						// Store index positions.
						NODE.value.start = STATE.i;
						NODE.value.end = STATE.i;
						NODE.value.value = char; // Start building string.
					} else {
						// If flag is set and characters can still be consumed
						// then there is a syntax error. For example, string
						// may be improperly quoted/escaped so give error.
						if (end_comsuming) error(STATE, __filename);

						// Get string type.
						let stype = NODE.value.type;

						// Escaped string logic.
						if (stype === "escaped") {
							if (r_whitespace.test(char) && pchar !== "\\") {
								end_comsuming = true; // Set flag.
							}

							// Quoted string logic.
						} else if (stype === "quoted") {
							let value_fchar = NODE.value.value.charAt(0);
							if (char === value_fchar && pchar !== "\\") {
								end_comsuming = true; // Set flag.
							}
						}

						// Store index positions.
						NODE.value.end = STATE.i;
						NODE.value.value += char; // Continue building string.
					}
				}

				break;
		}
	}

	validate(STATE, NODE); // Validate extracted variable value.
	add(STATE, NODE); // Add node to tree.
};
