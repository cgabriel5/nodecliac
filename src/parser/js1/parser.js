"use strict";

const flatry = require("flatry");
const state = require("./helpers/state.js");
const error = require("./helpers/error.js");
const tracer = require("./helpers/trace.js");
const { hasProp } = require("./utils/toolbox.js");
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
		let c = text.charAt(S.i);
		let n = text.charAt(S.i + 1);

		// Handle newlines.
		if (cin(C_NL, c)) {
			p_newline(S);
			continue;
		}

		// Handle inline comment.
		if (c === "#" && S.sol_char) {
			tracer(S, "comment");
			require("./parsers/comment.js")(S, true);
			continue;
		}

		// Store line start index.
		if (!hasProp(linestarts, S.line)) linestarts[S.line] = S.i;

		// Start parsing at first non-ws character.
		if (!S.sol_char && cnotin(C_SPACES, c)) {
			S.sol_char = c;

			// Sol c must be allowed.
			if (cnotin(C_SOL, c)) error(S, 10);

			ltype = linetype(S, c, n);
			if (ltype === "terminator") break;

			specificity(S, ltype, __filename);

			tracer(S, ltype);
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
