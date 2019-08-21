"use strict";

// Needed modules.
let issue = require("./helper.issue.js");
let { r_nl, r_whitespace, r_quote } = require("./h.patterns.js");

/**
 * Parses flag option line.
 *
 * ---------- Parsing States Breakdown -----------------------------------------
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
	require("./helper.trace.js")(STATE); // Trace parser.

	// Note: If a flag scope doesn't exist, error as it needs to.
	require("./helper.brace-checks.js")(STATE, null, "pre-existing-fs");

	// Get global loop state variables.
	let { line, l, string } = STATE;

	// Parsing vars.
	let state = "bullet"; // Initial parsing state.
	let qchar;
	let warnings = []; // Collect all parsing warnings.
	let end_comsuming;
	let NODE = {
		node: "OPTION",
		bullet: { start: null, end: null, value: null },
		value: { start: null, end: null, value: null, type: null },
		line,
		startpoint: STATE.i,
		endpoint: null // Then index at which parsing was ended.
	};

	// Loop over string.
	for (; STATE.i < l; STATE.i++) {
		let char = string.charAt(STATE.i); // Cache current loop item.

		// End loop on a new line char.
		if (r_nl.test(char)) {
			// Note: When setting the endpoint make sure to subtract index
			// by 1 so that when it returns to its previous loop is can run
			// the newline character code block.
			NODE.endpoint = STATE.i - 1; // Store newline index.
			STATE.i = STATE.i - 1; // Store newline index.
			break;
		}

		STATE.column++; // Increment column position.

		switch (state) {
			case "bullet":
				// Store '-' bullet index positions.
				NODE.bullet.start = STATE.i;
				NODE.bullet.end = STATE.i;
				// Start building the value string.
				NODE.bullet.value = char;

				// Change state to whitespace-boundary after bullet.
				state = "spacer";

				break;

			case "spacer":
				// A whitespace character must follow the bullet.
				if (!r_whitespace.test(char)) {
					issue.error(STATE);
				}

				// Set state to collect comment characters.
				state = "wsb-prevalue";

				break;

			case "wsb-prevalue":
				// Note: Allow any whitespace until first non-whitespace
				// character is hit.
				if (!/[ \t]/.test(char)) {
					// Note: Rollback index by 1 to allow parser to
					// start at new state on next iteration.
					STATE.i -= 1;
					STATE.column--;

					state = "value";
				}

				break;

			case "value":
				// Value:
				// - Command-flags: $("cat")
				// - Strings: "value"
				// - Escaped-values: val\ ue

				// Get the previous char.
				let pchar = string.charAt(STATE.i - 1);

				// Determine value type.
				if (!NODE.value.value) {
					if (char === "$") {
						NODE.value.type = "command-flag";
					} else if (char === "(") {
						NODE.value.type = "list";
					} else if (/["']/.test(char)) {
						NODE.value.type = "quoted";
					} else {
						NODE.value.type = "escaped";
					}

					// Store index positions.
					NODE.value.start = STATE.i;
					NODE.value.end = STATE.i;
					// Start building the value string.
					NODE.value.value = char;
				} else {
					// If flag is set and characters can still be consumed
					// then there is a syntax error. For example, string may
					// be improperly quoted/escaped so give error.
					if (end_comsuming) {
						issue.error(STATE);
					}

					// Get string type.
					let stype = NODE.value.type;

					// Escaped string logic.
					if (stype === "escaped") {
						if (/[ \t]/.test(char) && pchar !== "\\") {
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
					// Continue building the value string.
					NODE.value.value += char;
				}

				break;
		}
	}

	// Validate extracted variable value.
	require("./helper.validate-value.js")(STATE, NODE);

	// Add node to tree.
	require("./helper.tree-add.js")(STATE, NODE);

	return NODE;
};
