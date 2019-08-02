"use strict";

// Get needed modules.
const path = require("path");
const chalk = require("chalk");
const { exit } = require("../utils/exit.js");

// Error lookup table.
let errors = {
	command: {
		0: "Invalid character:"
	},
	comment: {
		0: "Invalid character:"
	},
	flag: {
		0: "Invalid character:"
	},
	variable: {
		0: "Invalid character:"
	},
	setting: {
		0: "Invalid character:"
	},
	"template-string": {
		0: "Invalid character:"
	}
};

let issue = (STATE, code, filepath) => {};
issue.error = (STATE, code, filepath) => {
	// Get file name from file path.
	let filename = path.basename(filepath).replace(/^parser\.|\.js/g, "");
	console.log("Error", code, `${STATE.line}:${STATE.column}`);

	// Get error from lookup table.
	let error = errors[filename][code];

	// Log error and exit process.
	exit([error]);
};
issue.warning = (STATE, code, filename) => {};

module.exports = issue;
