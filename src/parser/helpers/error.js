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
		10: "Illegal escape sequence"
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
		14: "Useless comma delimiter",
		15: "Illegal list syntax"
	}
};

/**
 * Print error and kill process.
 *
 * @param  {object} S - State object.
 * @param  {number} code - Error code.
 * @param  {string} parserfile - Path of parser issuing error.
 * @return {undefined} - Nothing is returned.
 */
module.exports = (S, parserfile, code) => {
	let { line, column } = S;
	let { source } = S.args;
	let parser = path.basename(parserfile).replace(/\.js$/, "");

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
