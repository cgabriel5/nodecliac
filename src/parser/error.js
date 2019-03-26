// Needed modules.
const chalk = require("chalk");
const { exit } = require("../utils.js");

/**
 * Issue warnings and or error the parsing result object might contain.
 *
 * @param  {object} result - The parsing result object.
 * @return {undefined} - Logs warnings. Exits script if error is issued.
 */
let verify = (result, warnings) => {
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
		issue(result);
	}
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
let issue = (result, type = "error") => {
	// Use provided line num/char index position.
	let line = result.line;
	let index = result.index;

	// Determine highlight label color.
	let color = type === "error" ? "red" : "yellow";

	// Build line info.
	let lineinfo = `line ${line}`;
	if (index) {
		lineinfo += `:${index}`;
	}

	// Print issue.
	exit(
		[`[${chalk.bold[color](type)}] ${result.reason} [${lineinfo}]`],
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
let error = (char = "", code, line, index) => {
	// Replace whitespace characters with their respective symbols.
	char = char.replace(/ /g, "␣").replace(/\t/g, "⇥");

	// Parsing error reasons.
	let reasons = {
		0: `Unexpected start-of-line character '${char}'.`,
		1: "Command chain cannot be nested.",
		2: `Unexpected character '${char}'.`,
		3: "Improperly nested flag option.",
		4: "Improperly nested flag.",
		5: "Rogue flag/flag option. Must be placed inside '[]'.",
		6: `Line cannot begin with whitespace.`,
		7: `Unmatched '${char}'.`,
		8: `Unclosed '${char}'.`
	};

	// Issue error.
	verify({
		line,
		index,
		code,
		char,
		reason: reasons[code]
	});
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
		warnings
	} = args;

	// Determine which data set to use.
	let data = /[\[\]]|brackets/.test(brace_style)
		? last_open_br
		: last_open_pr;

	if (!data) {
		if (issue === "unmatched") {
			error(brace_style, 7, void 0, indentation.length);
		}
	} else {
		// Get information on last opened brace matching style provided.
		let [line, index] = data;

		if (issue === "unclosed") {
			error(brace_style, 7, line, index);
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
