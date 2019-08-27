"use strict";

// Needed modules.
const path = require("path");
const chalk = require("chalk");

/**
 * Print parser being used.
 *
 * @return {undefined} - Nothing is returned.
 */
module.exports = (STATE, parser) => {
	// Get file invoking issue.
	let parsername = parser.replace(/\.js$/g, "");

	// Only trace if flag is set.
	if (!STATE.args.trace) {
		return;
	}

	let line_num = STATE.line;
	let last_line_num = STATE.last_line_num;
	let filename = path
		.basename(path.relative(process.cwd(), parsername))
		.replace(/\.js$/, "");

	// Print header.
	if (!last_line_num) {
		console.log(`\n${chalk.magenta.bold.underline("Trace")}`);
	}

	// Set line number.
	STATE.last_line_num = line_num;
	// Set indentation.
	STATE.trace_indentation = "";

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
