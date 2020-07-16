"use strict";

const flatry = require("flatry");
const state = require("./helpers/state.js");
const error = require("./helpers/error.js");
const { hasProp } = require("../utils/toolbox.js");
const formatter = require("./tools/formatter.js");
const p_newline = require("./parsers/newline.js");
const linetype = require("./helpers/line-type.js");
const specificity = require("./helpers/specificity.js");
const bracechecks = require("./helpers/brace-checks.js");
const { cin, cnotin, C_NL, C_SOL, C_SPACES } = require("./helpers/charsets.js");

module.exports = async (
	action,
	text,
	cmdname,
	source,
	fmt,
	trace,
	igc,
	test
) => {
	const S = state(action, cmdname, text, source, fmt, trace, igc, test);
	const { linestarts } = S.tables;
	// const stime = process.hrtime();
	let ltype;

	for (; S.i < S.l; S.i++, S.column++) {
		let char = text.charAt(S.i);
		let nchar = text.charAt(S.i + 1);

		// Handle newlines.
		if (cin(C_NL, char)) {
			p_newline(S);
			continue;
		}

		// Store line start index.
		if (!hasProp(linestarts, S.line)) linestarts[S.line] = S.i;

		// Start parsing at first non-ws character.
		if (!S.sol_char && cnotin(C_SPACES, char)) {
			S.sol_char = char;

			// Sol char must be allowed.
			if (cnotin(C_SOL, char)) error(S, __filename, 10);

			ltype = linetype(S, char, nchar);
			if (ltype === "terminator") break;

			specificity(S, ltype, __filename);

			require("./helpers/trace.js")(S, ltype);
			require(`./parsers/${ltype}.js`)(S);
		}
	}

	// Error if cc scope exists post-parsing.
	bracechecks(S, null, "post-standing-scope");

	let res = {};
	if (action === "format") res.formatted = formatter(S);
	else [, res] = await flatry(require("./tools/acdef.js")(S, cmdname));
	return res;
};
