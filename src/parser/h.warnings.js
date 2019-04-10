"use strict";

// Needed modules.
const path = require("path");
const chalk = require("chalk");

// Get globals.
let warnings = global.$app.get("warnings"); // Get warnings.

/**
 * Prints parser warnings.
 *
 * @return {undefined} - Nothing is returned.
 *
 * @resource [https://stackoverflow.com/a/8228308]
 */
module.exports = (issue, source) => {
	// Track longest (line + index) column to evenly space line/char.
	let line_col_length = 0;
	// Track longest parser name column to evenly space line/char.
	let line_col_fpname = 0;

	// Return if warnings array is empty (no warnings to log).
	if (!warnings.length) {
		return;
	}

	// Order warnings by line number then issue.
	warnings = warnings.sort(function(a, b) {
		// [https://coderwall.com/p/ebqhca/javascript-sort-by-two-fields]
		// [https://stackoverflow.com/a/13211728]
		return a.line - b.line || a.index - b.index;
	});

	// Add warnings header if warnings exist.
	if (warnings.length) {
		console.log();
		console.log(
			`${chalk.bold.underline(path.relative(process.cwd(), source))}`
		);
	}

	for (let i = 0, l = warnings.length; i < l; i++) {
		// Cache current loop item.
		issue(warnings[i], "warn", warnings);
	}

	// Print bottom padding.
	console.log();
};
