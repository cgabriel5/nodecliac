"use strict";

// Needed modules.
const path = require("path");
const chalk = require("chalk");

/**
 * Prints parser warnings.
 *
 * @return {undefined} - Nothing is returned.
 *
 * @resource [https://stackoverflow.com/a/8228308]
 */
module.exports = (warnings, issue, source) => {
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
		// Store line + index length;
		let line_col_size = (a.line + ":" + (a.index || "0")).length;
		if (line_col_size > line_col_length) {
			line_col_length = line_col_size;
		}
		// Re-do calculation with item b.
		line_col_size = (b.line + ":" + (b.index || "0")).length;
		if (line_col_size > line_col_length) {
			line_col_length = line_col_size;
		}

		// Store parser name length;
		let src_col_size = a.source.length;
		if (src_col_size > line_col_fpname) {
			line_col_fpname = src_col_size;
		}
		// Re-do calculation with item b.
		src_col_size = b.source.length;
		if (src_col_size > line_col_fpname) {
			line_col_fpname = src_col_size;
		}
		// [TODO] ^ Find better solution to avoid redundant calculations.

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
		issue(warnings[i], "warn", line_col_length, line_col_fpname);
	}

	// Print bottom padding.
	console.log();
};
