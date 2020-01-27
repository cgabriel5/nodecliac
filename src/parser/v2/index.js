"use strict";

module.exports = (string, commandname, source, formatting, ...args) => {
	const [highlight, trace, stripcomments, test] = args;
	const stime = process.hrtime(); // Start time.
	let first_non_whitespace_char = "";
	let line_type;

	// Loop state object.
	const STATE = {
		line: 1,
		column: 0,
		i: 0,
		l: string.length,
		string,
		specificity: 0, // Default to allow anything initially.
		scopes: { command: null, flag: null }, // Track command/flag scopes.

		// Parsing lookup tables.
		tables: { variables: {}, linestarts: {}, tree: { nodes: [] } },

		// Arguments/parameters for quick access across parsers.
		args: { formatting, highlight, trace, stripcomments, test },

		// Utilities (helper functions/constants) for quick access.
		utils: {
			constants: { regexp: require("./helpers/patterns.js") },
			functions: {
				tree: { add: require("./helpers/tree-add.js") },
				loop: {
					issue: require("./helpers/issue.js"),
					rollback: require("./helpers/rollback.js"),
					validate: require("./helpers/validate-value.js"),
					bracechecks: require("./helpers/brace-checks.js")
				}
			}
		}
	};

	// Main loop helper functions/constants.
	const linetype = require("./helpers/line_type.js");
	const formatter = require("./helpers/formatter.js");
	const specificity = require("./helpers/specificity.js");
	const bracechecks = require("./helpers/brace-checks.js");
	const { r_start_line_char } = STATE.utils.constants.regexp;
	const { issue } = STATE.utils.functions.loop;
	const { linestarts } = STATE.tables;

	// Loop over acdef file contents to parse.
	for (; STATE.i < STATE.l; STATE.i++) {
		let char = string.charAt(STATE.i); // Cache current loop char.
		let nchar = string.charAt(STATE.i + 1);

		// Handle newlines.
		if (char === "\n") {
			require(`./parsers/newline.js`)(STATE); // Run newline parser.

			STATE.line++; // Increment line count.
			STATE.column = 0; // Reset column to zero.
			first_non_whitespace_char = "";

			continue; // Skip iteration at this point.
		}

		STATE.column++; // Increment column position.

		// Store line start points.
		if (!linestarts[STATE.line]) linestarts[STATE.line] = STATE.i;

		// Find first non-whitespace character of line.
		if (!first_non_whitespace_char && !/[ \t]/.test(char)) {
			first_non_whitespace_char = char; // Set flag.

			// Error if sol char is not allowed.
			if (!r_start_line_char.test(char)) issue.error(STATE, 10);

			// Note: Since current sol char has already been iterated over,
			// rollback column to let parser start on sol char.
			STATE.column--;

			line_type = linetype(STATE, char, nchar); // Get line's type.
			if (line_type === "terminator") break; // End on terminator char.

			specificity(STATE, line_type); // Validate line specificity.

			let parser = `${line_type}.js`;
			require("./helpers/trace.js")(STATE, parser); // Trace parser.
			require(`./parsers/${parser}`)(STATE); // Finally, run parser.
		}
	}

	// If command-chain scope exists post-parsing then it was never closed.
	bracechecks(STATE, null, "post-standing-scope");

	let res = {};
	if (formatting) res.formatted = formatter(STATE);
	else res = require("./helpers/acdef.js")(STATE, commandname);
	res.time = process.hrtime(stime); // Attach end time.
	return res; // Return acdef, config, etc.
};
