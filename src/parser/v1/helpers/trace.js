"use strict";

// Needed modules.
const path = require("path");
const chalk = require("chalk");
// Setup app global variables.
const globals = require("../helpers/globals.js");

/**
 * Print parser being used.
 *
 * @param  {string} p - Parser filepath.
 * @return {undefined} - Nothing is returned.
 */
module.exports = p => {
	// Get globals.
	let trace = globals.get("trace");

	// Only trace if flag is set.
	if (!trace) {
		return;
	}

	let line_num = globals.get("line_num");
	let last_line_num = globals.get("last_line_num");
	let filename = path
		.basename(path.relative(process.cwd(), p))
		.replace(/^p.|\.js$/g, "");

	// Print header.
	if (!last_line_num) {
		console.log(`\n${chalk.magenta.bold.underline("Trace")}`);
	}

	// Set line number.
	globals.set("last_line_num", line_num);
	// Set indentation.
	globals.set("trace_indentation", "");

	// Append to last logged terminal line: [https://stackoverflow.com/a/17309876]

	// If a new unique line number.
	if (line_num !== last_line_num) {
		process.stdout.write(`  ${chalk.bold(line_num)} ${filename}:\n`);
	}
	// Else append parser to current parser chain.
	else {
		process.stdout.write(`    — ${chalk.dim(filename)}\n`);
	}
};
