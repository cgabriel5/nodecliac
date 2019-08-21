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
module.exports = issue => {
	// Get globals.
	let source = global.$app.get("source");
	let warnings = global.$app.get("warnings");

	// Only print empty line to pad output when no warnings exist.
	if (!warnings.length) {
		return console.log();
	}

	// Order warnings by line number then issue.
	warnings = warnings.sort(function(a, b) {
		// [https://coderwall.com/p/ebqhca/javascript-sort-by-two-fields]
		// [https://stackoverflow.com/a/13211728]
		return a.line - b.line || a.index - b.index;
	});

	// Add warnings header if warnings exist.
	console.log(
		`\n${chalk.bold.underline(path.relative(process.cwd(), source))}`
	);

	for (let i = 0, l = warnings.length; i < l; i++) {
		// Cache current loop item.
		issue(warnings[i], "warn", warnings);
	}

	// Print bottom padding.
	console.log();
};
