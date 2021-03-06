"use strict";

const path = require("path");
const chalk = require("chalk");

let errors = {
	"*": {
		0: "Syntax: Unexpected character"
	},
	index: {
		10: "Illegal start-of-line character",
		12: "Check line specificity order"
	},
	command: {
		10: "Illegal escape sequence",
		11: "Empty command group",
		12: "Useless delimiter",
		13: "Unclosed command group"
	},
	comment: {},
	flag: {
		10: "Flag declared out of scope",
		11: "Flag declared within flag scope"
	},
	option: {},
	variable: {},
	setting: {},
	"close-brace": {},
	"brace-checks": {
		10: "Command declared out of scope",
		11: "Can't close an unopened command scope",
		12: "Unclosed scope",
		13: "Flag option declared out of scope"
	},
	"template-string": {},
	validate: {
		10: "Improperly quoted string",
		11: "String cannot be empty",
		12: "Undefined variable",
		13: "Illegal command-flag syntax",
		14: "Useless delimiter",
		15: "Illegal list syntax",
		16: "Keyword cannot be valueless",
		17: "Illegal exclude"
	},
	vcontext: {
		14: "Useless delimiter",
		16: "Missing flag conditions",
		17: "Unclosed brace"
	},
	vtest: {
		14: "Useless delimiter",
		15: "Malformed test string"
	}
};

/* Programmatically gets the filename where error occurred (file name
*     where function was called).
*
* @param  {object} S - State object.
* @param  {number} code - Error code.
* @param  {string} parserfile - Path of parser issuing error.
* @return - Nothing is returned.
*/
function get_caller_file() {
	var originalFunc = Error.prepareStackTrace;

	var callerfile;
	try {
		var err = new Error();
		var currentfile;

		Error.prepareStackTrace = function (err, stack) { return stack; };

		currentfile = err.stack.shift().getFileName();

		while (err.stack.length) {
			callerfile = err.stack.shift().getFileName();
			if(currentfile !== callerfile) break;
		}
	} catch (e) {}

	Error.prepareStackTrace = originalFunc;

	return callerfile;
}

/* Print error and kill process. Programmatically gets the filename where
*     the error occurred (file name where function was called). This is
*     better than using `currentSourcePath` everywhere.
*
* @param  {object} S - State object.
* @param  {number} code - Error code.
* @param  {string} parserfile - Path of parser issuing error.
* @return - Nothing is returned.
*/
module.exports = (S, code = 0, parserfile = "") => {
	// [https://stackoverflow.com/a/29581862]
	let fullpath = parserfile || get_caller_file()

	let { line, column } = S;
	let { source } = S.args;
	let parser = path.basename(fullpath).replace(/\.js$/, "");

	if (!code) code = 0; // Use default if code doesn't exist.
	let error = errors[code ? parser : "*"][code];

	let pos = chalk.bold.red(`${line}:${column}`);
	let einfo = "[" + chalk.red("err") + ` ${parser},${code}` + "]";

	// Truncate source file path if too long.
	let dirs = source.split(path.sep);
	if (dirs.length >= 5) {
		dirs = dirs.slice(dirs.length - 3);
		source = "..." + dirs.join(path.sep);
	}

	let filename = chalk.bold(path.basename(source));
	let dirname = path.dirname(source);

	console.log(`${einfo} ${dirname}/${filename}:${pos} — ${error}`);
	process.exit();
};
