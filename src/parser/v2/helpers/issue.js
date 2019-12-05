"use strict";

const path = require("path");
const chalk = require("chalk");
const { exit } = require("../../../utils/toolbox.js");

// Error lookup table.
let errors = {
	"*": {
		// Universal errors.
		error: { 0: "Unexpected character (syntax error)." },
		warning: {}
	},
	index: {
		10: "Illegal start-of-line character.",
		11: "Line cannot begin with whitespace.",
		12: "Check line specificity order."
	},
	command: {
		10: "Illegal escape sequence."
	},
	comment: {},
	flag: {
		10: "Cannot declare flag out of scope.",
		11: "Cannot declare flag within flag scope."
	},
	option: {},
	variable: {},
	setting: {},
	"close-brace": {},
	"brace-checks": {
		10: "Cannot declare command within command scope.",
		11: "Cannot close an unopened command scope.",
		12: "Unclosed scope.",
		13: "Cannot declare flag option out of scope."
	},
	"template-string": {},
	"validate-value": {
		10: "Improperly quoted string.",
		11: "String cannot be empty.",
		12: "Undefined variable.",
		13: "Illegal command-flag syntax.",
		14: "Useless comma delimiter.",
		15: "Illegal list syntax."
	}
};

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

		Error.prepareStackTrace = (err, stack) => stack;
		currentfile = err.stack.shift().getFileName();

		while (err.stack.length) {
			callerfile = err.stack.shift().getFileName();
			if (currentfile !== callerfile) break;
		}

		// eslint-disable-next-line no-empty
	} catch (e) {}

	Error.prepareStackTrace = originalFunc;

	// Get file name from file path.
	return path.basename(callerfile).replace(/^(parser|helper)\.|\.js/g, "");
};

/**
 * Main issue function. Acts as a wrapper for its error/warning methods.
 *
 * @return {undefined} - Nothing is returned.
 */
let issue = () => {};

/**
 * Issues error. Note: Also kills process.
 *
 * @param  {object} STATE - The global STATE object.
 * @param  {number} code - The error code.
 * @return {undefined} - Nothing is returned.
 */
issue.error = (STATE, code) => {
	const { line, column } = STATE;
	const X_MARK = chalk.bold.red("❌");
	const callerfile = caller_filename(); // Get file invoking issue.
	let error, msg;

	// Get error (use default if code doesn't exist).
	if (!code) {
		code = 0; // Reset to default error.
		error = errors["*"].error[code];
	} else error = errors[callerfile][code];

	error = chalk.bold(error); // Decorate error.
	msg = `  ${X_MARK}  ${line}:${column} ${callerfile} (E${code}) ${error}`;
	exit.normal([msg], undefined); // Print error and stop script.
};

/**
 * Issues warning.
 *
 * @param  {object} STATE - The global STATE object.
 * @param  {number} code - The warning code.
 * @return {undefined} - Nothing is returned.
 */
// issue.warning = (STATE, code) => {};

module.exports = issue;
