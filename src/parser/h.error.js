"use strict";

// Needed modules.
const path = require("path");
const chalk = require("chalk");
const { exit } = require("../utils/toolbox.js");

// Get highlighter.
const h = global.$app.get("highlighter");

// Name of main script file (for error purposes).
const sourcescript = "p.main.js";

/**
 * Issue warnings and or error the parsing result object might contain.
 *
 * @param  {object} result - The parsing result object.
 * @return {undefined} - Logs warnings. Exits script if error is issued.
 */
let verify = result => {
	// Get globals.
	let source = global.$app.get("source");
	let warnings = global.$app.get("warnings");

	// Get warnings from result object.
	let warns = result.warnings || [];

	/**
	 * Calculate/attach max column lengths for index:line and parser name.
	 *
	 * @param  {object} issue - The parsing result object.
	 * @return {object} - The issue object.
	 */
	let max_col_lengths = issue => {
		// Calculate index:line, parser name column lengths.
		let col_line = (issue.line + ":" + (issue.index || "0")).length;
		let col_pname = issue.source.length;

		// Attach if length is larger than currently attached length.
		if (col_line > (warnings.col_line || 0)) {
			warnings.col_line = col_line;
		}
		if (col_pname > (warnings.col_pname || 0)) {
			warnings.col_pname = col_pname;
		}

		// Return object.
		return issue;
	};

	// Print warnings.
	if (warns.length) {
		for (let i = 0, ll = warns.length; i < ll; i++) {
			// Calculate max column lengths then store warning object.
			warnings.push(max_col_lengths(warns[i]));
		}
	}

	// Issue error if present.
	if (result.hasOwnProperty("code")) {
		// Calculate max column lengths.
		max_col_lengths(result);

		// Add warnings header if warnings exist.
		console.log();
		console.log(
			`${chalk.bold.underline(path.relative(process.cwd(), source))}`
		);

		issue(result);
	}

	// Return result object.
	return result;
};

/**
 * Issues warnings/error. Warnings are non-obtrusive as they simply get
 *     logged to the console. When an error is issued the script will
 *     exit after logging error to the console.
 *
 * @param  {object} data - The result object.
 * @param  {string} type - The issue type (error/warning).
 * @param  {array} warnings - The array of warning objects.
 * @return {undefined} - Logs warnings. Exits script if error is issued.
 */
let issue = (result, type = "error", warnings = []) => {
	// Use provided line num/char index position.
	let line = result.line;
	let index = result.index;
	let pname = result.source; // Get name of parser issuing error/warning.

	// Calculate line:index column remainder.
	let remainder = warnings.col_line - (line + ":" + index).length;
	remainder = remainder < 0 ? 0 : remainder;
	// Calculate parser name column remainder.
	let fremainder = warnings.col_pname - pname.length;
	fremainder = fremainder < 0 ? 0 : fremainder;

	// Determine highlight label color/issue symbol.
	let color = type === "error" ? "red" : "yellow";
	let symbol = type === "error" ? "❌" : "⚠";

	// Note: The character's (position) index should never be negative. If
	// it's negative the the index was not properly set. To easily detect
	// negative indices highlight them red.
	if (index < 0) {
		// Highlight red for visual feedback.
		index = chalk.red.bold(index);
	}

	// Build line info.
	let lineinfo = `${line}`;
	if (index !== undefined) {
		lineinfo += `:${index}`;
	}

	// The text to log to console.
	let data = [
		`  ${chalk.bold[color](symbol)}  ${lineinfo}${" ".repeat(
			// Note: When remainder is negative set to 0.
			remainder
		)}  ${h(pname.replace(/(p\.|\.js)/g, ""), "comment")}${" ".repeat(
			// Note: When remainder is negative set to 0.
			fremainder
		)}  ${result.reason}`
	];

	// Add bottom padding for error.
	if (type === "error") {
		data.push("");
	}

	// Print issue.
	exit.normal(
		data,
		// If issuing an error stop script after printing error.
		type === "error" ? undefined : false
	);
};
/**
 * Generate parsing error.
 *
 * @param  {string} reason - The error's reason.
 * @param  {number} line - The line error occurred.
 * @param  {number} index - The char index error occurred.
 * @return {undefined} - Nothing is returned.
 */
let error = (char = "", code, line, index, source) => {
	// Replace whitespace characters with their respective symbols.
	char = char.replace(/\s/g, function(match) {
		let lookup = {
			"\n": "↵",
			"\t": "⇥",
			" ": "␣"
		};

		// Return white character symbol.
		return lookup[match];
	});

	// Get character type.
	let ctype = char && Number(char) ? "number" : "character";

	// Add syntax highlight.
	char = h(char, "value");

	// Parsing error reasons.
	let reasons = {
		0: `Unexpected start-of-line ${ctype}: '${char}'.`,
		1: "Command chain cannot be nested.",
		2: `Unexpected ${ctype}: '${char}'.`,
		3: "Improperly nested flag option.",
		4: "Improperly nested flag.",
		5: "Invalid line.",
		6: `Line cannot begin with whitespace.`,
		7: `Unmatched '${char}'.`,
		8: `Unclosed '${char}'.`
	};

	// Issue error.
	verify(
		{
			line,
			index,
			code,
			char,
			reason: reasons[code],
			// Add key to denote file giving issue.
			source: sourcescript
		},
		[],
		source
	);
};

/**
 * Issue warning for unmatched/unclosed/empty braces.
 *
 * @param  {string} issue - Type of issue to give (unclosed/unmatched).
 * @param  {string} brace_style - Brace style (bracket/parentheses).
 * @return {undefined} - Nothing is returned.
 */
let brace_check = args => {
	// Get arguments.
	let { issue, brace_style, last_open_br, last_open_pr } = args;

	// Get globals.
	let source = global.$app.get("source");
	let warnings = global.$app.get("warnings");
	let indentation = global.$app.get("indentation");

	// Determine which data set to use.
	let data = /[[\]]|brackets/.test(brace_style) ? last_open_br : last_open_pr;

	if (!data) {
		if (issue === "unmatched") {
			error(brace_style, 7, void 0, indentation.length, source);
		}
	} else {
		// Get information on last opened brace matching style provided.
		let [line, index] = data;

		if (issue === "unclosed") {
			error(brace_style, 7, line, index, source);
		} else if (issue === "empty") {
			// Add warning to warnings.
			warnings.push({
				line: line,
				index,
				reason: `Empty ${
					brace_style === "parentheses"
						? `'${h("()", "value")}' (no flag options)`
						: `'${h("[]", "value")}' (no flags)`
				}.`,
				// Add key to denote file giving issue.
				source: sourcescript
			});
		}
	}
};

/**
 * If an orphaned delimiter command-chain exists issue an error.
 *
 * @param  {array} data - Tuple containing line/index of error.
 * @return {undefined} - Nothing is returned.
 */
let orphaned_cmddel_check = data => {
	if (data) {
		// Get line information.
		let [line, index] = data;

		// Issue error.
		error(",", 2, line, index, sourcescript);
	}
};

module.exports = {
	orphaned_cmddel_check,
	verify,
	issue,
	error,
	brace_check
};
