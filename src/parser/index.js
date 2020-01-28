"use strict";

const state = require("./helpers/state.js");
const error = require("./helpers/error.js");
const p_newline = require("./parsers/newline.js");
const linetype = require("./helpers/line_type.js");
const formatter = require("./helpers/formatter.js");
const specificity = require("./helpers/specificity.js");
const bracechecks = require("./helpers/brace-checks.js");
const { r_sol_char, r_space } = require("./helpers/patterns.js");

module.exports = (text, commandname, source, fmt, trace, igc, test) => {
	const S = state(text, source, fmt, trace, igc, test);
	const { linestarts } = S.tables;
	const stime = process.hrtime(); // Start time.
	let line_type;

	// Loop over acdef file contents to parse.
	for (; S.i < S.l; S.i++) {
		let char = text.charAt(S.i);
		let nchar = text.charAt(S.i + 1);

		// Handle newlines.
		if (char === "\n") p_newline(S);
		// All other characters.
		else {
			S.column++;

			// Store line start points.
			if (!linestarts[S.line]) linestarts[S.line] = S.i;

			// Find first non-whitespace character of line.
		if (!S.sol_char && !r_space.test(char)) {
				S.sol_char = char; // Set char.

				// Error if sol char is not allowed.
				if (!r_sol_char.test(char)) error(S, 10, __filename);

				line_type = linetype(S, char, nchar); // Get line's type.
				if (line_type === "terminator") break; // End on terminator char.

				specificity(S, line_type); // Validate line specificity.

				S.column--; // Rollback column to start parser on sol char.
				require("./helpers/trace.js")(S, line_type); // Trace parser.
				require(`./parsers/${line_type}.js`)(S); // Run parser.
			}
		}
	}

	// If command-chain scope exists post-parsing then it was never closed.
	bracechecks(S, null, "post-standing-scope");

	let res = {};
	if (fmt) res.formatted = formatter(S);
	else res = require("./helpers/acdef.js")(S, commandname);
	res.time = process.hrtime(stime); // Attach end time.
	return res; // Return acdef, config, etc.
};
