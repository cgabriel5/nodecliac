// Needed modules.
const path = require("path");
const chalk = require("chalk");
const { exit } = require("../utils.js");

/**
 * Issue warnings and or error the parsing result object might contain.
 *
 * @param  {object} result - The parsing result object.
 * @return {undefined} - Logs warnings. Exits script if error is issued.
 */
let verify = (result, warnings, source) => {
	// Get warnings from result object.
	let warns = result.warnings || [];

	// Print warnings.
	if (warns.length) {
		for (let i = 0, ll = warns.length; i < ll; i++) {
			// Store warning object.
			warnings.push(warns[i]);
		}
	}

	// Issue error if present.
	if (result.hasOwnProperty("code")) {
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
 * @return {undefined} - Logs warnings. Exits script if error is issued.
 */
let issue = (result, type = "error", col_size) => {
	// Use provided line num/char index position.
	let line = result.line;
	let index = result.index;

	// Store line + index length;
	let line_col_size = (line + "" + index).length;
	let remainder = col_size - line_col_size;

	// Determine highlight label color/issue symbol.
	let color = type === "error" ? "red" : "yellow";
	let symbol = type === "error" ? "❌" : "⚠";

	// Build line info.
	let lineinfo = `${line}`;
	if (index !== undefined) {
		lineinfo += `:${index}`;
	}

	// The text to log to console.
	let data = [
		`  ${chalk.bold[color](symbol)}  ${lineinfo}${" ".repeat(
			// Note: When remainder is negative set to 0.
			remainder < 0 ? 0 : remainder
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
	char = char.replace(/ /g, "␣").replace(/\t/g, "⇥");

	// Parsing error reasons.
	let reasons = {
		0: `Unexpected start-of-line character '${char}'.`,
		1: "Command chain cannot be nested.",
		2: `Unexpected character '${char}'.`,
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
			reason: reasons[code]
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
	let {
		issue,
		brace_style,
		last_open_br,
		last_open_pr,
		indentation,
		warnings,
		source
	} = args;

	// Determine which data set to use.
	let data = /[\[\]]|brackets/.test(brace_style)
		? last_open_br
		: last_open_pr;

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
						? "'()' (no flag options)"
						: "'[]' (no flags)"
				}.`
			});
		}
	}
};

module.exports = {
	verify,
	issue,
	error,
	brace_check
};
