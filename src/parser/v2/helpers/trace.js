"use strict";

// Needed modules.
const path = require("path");
const chalk = require("chalk");

/**
 * Get the filename that called the error function.
 *
 * @return {string} - The name of the file that called the function.
 *
 * @resource [https://stackoverflow.com/a/29581862]
 * @resource [https://stackoverflow.com/a/19788257]
 * @resource [https://v8.dev/docs/stack-trace-api]
 */
let caller_filename = () => {
	let originalFunc = Error.prepareStackTrace;

	let callerfile;
	try {
		let err = new Error();
		let currentfile;

		Error.prepareStackTrace = function(err, stack) {
			return stack;
		};

		currentfile = err.stack.shift().getFileName();

		while (err.stack.length) {
			callerfile = err.stack.shift().getFileName();

			if (currentfile !== callerfile) break;
		}
	} catch (e) {}

	Error.prepareStackTrace = originalFunc;

	// Get file name from file path.
	return path.basename(callerfile).replace(/^(parser|helper)\.|\.js/g, "");
};

/**
 * Print parser being used.
 *
 * @return {undefined} - Nothing is returned.
 */
module.exports = STATE => {
	// Get file invoking issue.
	let callerfile = caller_filename();

	// Only trace if flag is set.
	if (!STATE.args.trace) {
		return;
	}

	let line_num = STATE.line;
	let last_line_num = STATE.last_line_num;
	let filename = path
		.basename(path.relative(process.cwd(), callerfile))
		.replace(/^p.|\.js$/g, "");

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
