"use strict";

const state = require("./helpers/state.js");
const error = require("./helpers/error.js");
const p_newline = require("./parsers/newline.js");
const linetype = require("./helpers/line_type.js");
const formatter = require("./helpers/formatter.js");
const specificity = require("./helpers/specificity.js");
const bracechecks = require("./helpers/brace-checks.js");
const { r_sol_char, r_whitespace } = require("./helpers/patterns.js");

module.exports = (text, commandname, source, fmt, trace, igc, test) => {
	const STATE = state(text, source, fmt, trace, igc, test);
	const { linestarts } = STATE.tables;
	const stime = process.hrtime(); // Start time.
	let line_type;

	// Loop over acdef file contents to parse.
	for (; STATE.i < STATE.l; STATE.i++) {
		let char = text.charAt(STATE.i);
		let nchar = text.charAt(STATE.i + 1);

		// Handle newlines.
		if (char === "\n") p_newline(STATE);
		// All other characters.
		else {
			STATE.column++;

			// Store line start points.
			if (!linestarts[STATE.line]) linestarts[STATE.line] = STATE.i;

			// Find first non-whitespace character of line.
			if (!STATE.sol_char && !r_whitespace.test(char)) {
				STATE.sol_char = char; // Set char.

				// Error if sol char is not allowed.
				if (!r_sol_char.test(char)) error(STATE, 10, __filename);

				line_type = linetype(STATE, char, nchar); // Get line's type.
				if (line_type === "terminator") break; // End on terminator char.

				specificity(STATE, line_type); // Validate line specificity.

				STATE.column--; // Rollback column to start parser on sol char.
				require("./helpers/trace.js")(STATE, line_type); // Trace parser.
				require(`./parsers/${line_type}.js`)(STATE); // Run parser.
			}
		}
	}

	// If command-chain scope exists post-parsing then it was never closed.
	bracechecks(STATE, null, "post-standing-scope");

	let res = {};
	if (fmt) res.formatted = formatter(STATE);
	else res = require("./helpers/acdef.js")(STATE, commandname);
	res.time = process.hrtime(stime); // Attach end time.
	return res; // Return acdef, config, etc.
};
