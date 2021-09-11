#!/usr/bin/env node

"use strict";

// \033: [https://stackoverflow.com/a/10170631]

function issue_hint(filename, line, col, message) {
	let itype = "\u001b[32;1mHint:\u001b[0m";
	let fileinfo = "\u001b[1m" + filename + "(" + line + ", " + col + ")\u001b[0m";

	console.log(fileinfo + " " + itype + " " + message);
}

function issue_warn(filename, line, col, message) {
	let itype = "\u001b[33;1mWarning:\u001b[0m";
	let fileinfo = "\u001b[1m" + filename + "(" + line + ", " + col + ")\u001b[0m";

	console.log(fileinfo + " " + itype + " " + message);
}

function issue_error(filename, line, col, message) {
	let itype = "\u001b[31;1mError:\u001b[0m";
	let fileinfo = "\u001b[1m" + filename + "(" + line + ", " + col + ")\u001b[0m";

	console.log(fileinfo + " " + itype + " " + message);
	process.exit();
}

module.exports = { issue_hint, issue_warn, issue_error };
