"use strict";

const state = require("./helpers/state.js");
const error = require("./helpers/error.js");
const p_newline = require("./parsers/newline.js");
const linetype = require("./helpers/line_type.js");
const formatter = require("./helpers/formatter.js");
const specificity = require("./helpers/specificity.js");
const bracechecks = require("./helpers/brace-checks.js");
const { r_sol_char, r_space } = require("./helpers/patterns.js");

module.exports = (action, text, cmdname, source, fmt, trace, igc, test) => {
	const S = state(action, text, source, fmt, trace, igc, test);
	const { linestarts } = S.tables;
	const stime = process.hrtime();
	let line_type;

	for (; S.i < S.l; S.i++, S.column++) {
		let char = text.charAt(S.i);
		let nchar = text.charAt(S.i + 1);

		// Handle newlines.
		if (char === "\n") {
			p_newline(S);
			continue;
		}

		// Store line start index.
		if (!linestarts[S.line]) linestarts[S.line] = S.i;

		// Start parsing at first non-ws character.
		if (!S.sol_char && !r_space.test(char)) {
			S.sol_char = char;

			// Sol char must be allowed.
			if (!r_sol_char.test(char)) error(S, __filename, 10);

			line_type = linetype(S, char, nchar);
			if (line_type === "terminator") break;

			specificity(S, line_type);

			require("./helpers/trace.js")(S, line_type);
			require(`./parsers/${line_type}.js`)(S);
		}
	}

	// Check if command-chain scope exists post-parsing.
	bracechecks(S, null, "post-standing-scope");

	let res = {};
	if (action === "format") res.formatted = formatter(S);
	else res = require("./helpers/acdef.js")(S, cmdname);
	res.time = process.hrtime(stime);
	return res;
};
