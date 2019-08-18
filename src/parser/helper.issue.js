"use strict";

// Get needed modules.
const path = require("path");
const chalk = require("chalk");
const { exit } = require("../utils/exit.js");

// Error lookup table.
let errors = {
	"*": {
		// Universal errors.
		error: { 0: "Invalid character." },
		warning: {}
	},
	main: {},
	command: {},
	comment: {},
	flag: {},
	option: {},
	variable: {},
	setting: {},
	"close-brace": {},
	"brace-checks": {},
	"template-string": {},
	"validate-value": {}
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
	// Get file invoking issue.
	let callerfile = caller_filename();
	// Get error from lookup table.
	let error;
	if (!code) {
		// Use default error.
		error = errors["*"][1];
	} else {
		error = errors[callerfile][code];
	}

	// Reset when code is not provided.
	if (!code) {
		code = 0;
	}

	console.log("Error", code, `${STATE.line}:${STATE.column}`, callerfile);

	// Log error and exit process.
	exit([error]);
};

/**
 * Issues warning.
 *
 * @param  {object} STATE - The global STATE object.
 * @param  {number} code - The warning code.
 * @return {undefined} - Nothing is returned.
 */
issue.warning = (STATE, code) => {};

module.exports = issue;
