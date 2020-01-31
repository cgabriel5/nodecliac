"use strict";

const chalk = require("chalk");

/**
 * Basic tracing of parsers used for debugging.
 *
 * @return {undefined} - Nothing is returned.
 */
module.exports = (S, parser) => {
	if (!S.args.trace) return; // Only trace if flag is set.

	let msg;
	let line_num = S.line;
	let last_line_num = S.last_line_num;

	msg = `\n${chalk.magenta.bold.underline("Trace")}`;
	if (!last_line_num) console.log(msg); // Print header.

	S.last_line_num = line_num;
	S.trace_indentation = "";

	// Add to last printed line: [https://stackoverflow.com/a/17309876]

	msg = `${chalk.bold(line_num)} ${parser}\n`;
	if (line_num !== last_line_num) process.stdout.write(msg);
	else process.stdout.write(` ~ ${chalk.dim(parser)}\n`);
};
