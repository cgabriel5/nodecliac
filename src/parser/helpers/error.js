"use strict";

const path = require("path");
const chalk = require("chalk");

// Error lookup table.
let errors = {
	"*": {
		// Universal errors.
		error: { 0: "Unexpected character (syntax error)." },
		warning: {}
	},
	index: {
		10: "Illegal start-of-line character.",
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
	validate: {
		10: "Improperly quoted string.",
		11: "String cannot be empty.",
		12: "Undefined variable.",
		13: "Illegal command-flag syntax.",
		14: "Useless comma delimiter.",
		15: "Illegal list syntax."
	}
};

/**
 * Give error (kills process).
 *
 * @param  {object} S - The state object.
 * @param  {number} code - Error code.
 * @param  {string} parserfile - Path of file issuing error.
 * @return {undefined} - Nothing is returned.
 */
module.exports = (S, parserfile, code) => {
	let { line, column } = S;
	let { source } = S.args;
	let parser = path.basename(parserfile).replace(/\.js$/, "");
	let error;

	// Get error (use default if code doesn't exist).
	if (!code) {
		code = 0; // Reset to default error.
		error = errors["*"].error[code];
	} else error = errors[parser][code];

	let pos = chalk.bold.red(`${line}:${column}`);
	let einfo = "[" + chalk.red(`err`) + ` ${parser},${code}` + "]";

	// Truncate source file path if too large.
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
