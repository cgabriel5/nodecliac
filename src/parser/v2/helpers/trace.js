"use strict";

const path = require("path");
const chalk = require("chalk");

/**
 * Print parser being used.
 *
 * @return {undefined} - Nothing is returned.
 */
module.exports = (STATE, parser) => {
	let parsername = parser.replace(/\.js$/g, ""); // Get file invoking issue.

	if (!STATE.args.trace) return; // Only trace if flag is set.

	let msg;
	let line_num = STATE.line;
	let last_line_num = STATE.last_line_num;
	let basename = path.basename(path.relative(process.cwd(), parsername));
	let filename = basename.replace(/\.js$/, "");

	msg = `\n${chalk.magenta.bold.underline("Trace")}`;
	if (!last_line_num) console.log(msg); // Print header.

	STATE.last_line_num = line_num; // Set line number.
	STATE.trace_indentation = ""; // Set indentation.

	// Add to last printed line: [https://stackoverflow.com/a/17309876]

	// If a new unique line number.
	msg = `  ${chalk.bold(line_num)} ${filename}:\n`;
	if (line_num !== last_line_num) process.stdout.write(msg);
	// Append parser to current parser chain.
	else process.stdout.write(`    — ${chalk.dim(filename)}\n`);
};
