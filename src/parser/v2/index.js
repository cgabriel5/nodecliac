"use strict";

module.exports = (string, commandname, source, formatting, ...args) => {
	// Vars - destructure remaining arguments.
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
		specificity: 0, // Default to allow anything initially.

		// Track command-chain and flag scopes.
		scopes: { command: null, flag: null },

		// Parsing lookup tables.
		tables: {
			variables: {}, // Contain variables: name:value.
			linestarts: {}, // Contain line index start points.
			tree: { nodes: [] } // Collection of parsed NODES.
		},

		// Add arguments/parameters for easy access across parsers.
		args: {
			// commandname, source, nowarn,
			formatting,
			highlight,
			trace,
			stripcomments,
			test
		},

		// Attach utilities (helper functions/constants) for quick access.
		utils: {
			constants: {
				regexp: require("./helpers/patterns.js")
			},
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

	// Loop over acdef file contents to parse.
	for (; STATE.i < STATE.l; STATE.i++) {
		let char = string.charAt(STATE.i); // Cache current loop char.
		let nchar = string.charAt(STATE.i + 1);

		// Handle new lines.
		if (char === "\n") {
			require(`./parsers/newline.js`)(STATE); // Run newline parser.

			STATE.line++; // Increment line count.
			STATE.column = 0; // Reset column to zero.
			first_non_whitespace_char = "";

			continue; // Skip iteration at this point.
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
			if (!STATE.utils.constants.regexp.r_start_line_char.test(char)) {
				// Invalid start-of-line char.
				STATE.utils.functions.loop.issue.error(STATE, 10);
			}

			// Note: Since current sol char has already been iterated over,
			// rollback column to let parser start on sol char.
			STATE.column--;

			// Determine line's type.
			line_type = require("./helpers/line_type.js")(STATE, char, nchar);
			// Break from loop if terminator char found.
			if (line_type === "terminator") break;

			// Check line indentation.
			require("./helpers/indentation.js")(STATE, line_type);

			// Check line specificity hierarchy.
			require("./helpers/specificity.js")(STATE, line_type);

			let parser = `${line_type}.js`;
			require("./helpers/trace.js")(STATE, parser); // Trace parser.
			require(`./parsers/${parser}`)(STATE); // Finally, run parser.
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

		return res; // Return acdef, config, etc.
	}
};
