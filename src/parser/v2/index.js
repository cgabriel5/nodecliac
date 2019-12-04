"use strict";

// Get needed modules.
let issue = require("./helpers/issue.js");
let { r_start_line_char } = require("./helpers/patterns.js");

module.exports = (string, commandname, source, formatting, ...args) => {
	// Vars - second set of args.
	let [highlight, trace /* nowarn*/, , stripcomments, test] = args;

	// Vars - timers.
	let stime = process.hrtime(); // Store start time tuple array.
	// Vars - loop.
	let first_non_whitespace_char = "";
	let line_type;

	// Loop global state variables.
	const STATE = {
		// Loop variables.
		line: 1,
		column: 0,
		i: 0,
		l: string.length,
		string,
		loop: { rollback: require("./helpers/rollback.js") },
		specificity: 0, // Default to allow anything initially.

		// Parsing lookup tables.
		tables: {
			variables: {}, // Contain variables: name:value.
			linestarts: {}, // Contain line index start points.
			tree: {} // Line by line parsed tree nodes.
		},

		// Track command-chain and flag scopes.
		scopes: { command: null, flag: null },

		// Add arguments/parameters for easy access across parsers.
		args: {
			// commandname, source, nowarn,
			formatting,
			highlight,
			trace,
			stripcomments,
			test
		}
	};

	// Loop over acdef file contents to parse.
	for (; STATE.i < STATE.l; STATE.i++) {
		// Cache current loop item.
		let char = string.charAt(STATE.i);
		let nchar = string.charAt(STATE.i + 1);

		// Handle new lines.
		if (char === "\n") {
			// Run newline parser.
			require(`./parsers/newline.js`)(STATE);

			STATE.line++; // Increment line count.
			STATE.column = 0; // Reset column to zero.
			first_non_whitespace_char = "";

			// Skip iteration at this point.
			continue;
		}

		STATE.column++; // Increment column position.

		// Store line start points.
		if (!STATE.tables.linestarts[STATE.line]) {
			STATE.tables.linestarts[STATE.line] = STATE.i;
		}

		// Find first non-whitespace character of line.
		if (!first_non_whitespace_char && !/[ \t]/.test(char)) {
			first_non_whitespace_char = char; // Set flag.

			// Error if start-of-line character is not allowed.
			if (!r_start_line_char.test(char)) {
				issue.error(STATE, 10); // Invalid start-of-line char.
			}

			// Note: Since current sol char has already been iterated over,
			// rollback column to let parser start on sol char.
			STATE.column--;

			// Determine line's type.
			line_type = require("./helpers/line_type.js")(STATE, char, nchar);
			// Break from loop if terminator char found.
			if (line_type === "terminator") {
				break;
			}

			// Check line indentation.
			require("./helpers/indentation.js")(STATE, line_type);

			// Check line specificity hierarchy.
			require("./helpers/specificity.js")(STATE, line_type);

			// Finally, run parser.
			let parser = `${line_type}.js`;
			require("./helpers/trace.js")(STATE, parser); // Trace parser.
			require(`./parsers/${parser}`)(STATE);
		}
	}

	// If command-chain scope exists post-parsing then it was never closed.
	require("./helpers/brace-checks.js")(STATE, null, "post-standing-scope");

	if (formatting) {
		// Return prettified ACMAP.
		return {
			time: process.hrtime(stime), // Return end time tuple array.
			formatted: require("./helpers/formatter.js")(STATE)
		};
	} else {
		let res = require("./helpers/acdef.js")(STATE, commandname);
		res.time = process.hrtime(stime); // Return end time tuple array.

		// Return acdef, config, etc.
		return res;
	}
};
