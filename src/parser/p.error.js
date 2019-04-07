"use strict";

// Get needed modules.
const path = require("path");
const chalk = require("chalk");
const h = require("./h.highlighter.js");
const stripansi = require("strip-ansi");

module.exports = (...args) => {
	// Get arguments.
	let [
		,
		i,
		,
		line_num,
		line_fchar,
		filename,
		warnings,
		state,
		type,
		code,
		char,
		// Parser specific variables.
		fvars = {}
	] = args;

	// Get basename from file name.
	let scriptname = path.basename(filename);
	// Check if file is an intermediary file.
	let is_intermediary_file = /^p\.flag-(command|value)\.js$/.test(scriptname);

	// Define variables for specific parsers.
	let name = "",
		isvspecial,
		ci;
	if (scriptname === "p.flagset.js") {
		name = fvars.name;
		isvspecial = fvars.isvspecial;
	} else if (scriptname === "p.setting.js") {
		name = fvars.name;
	} else if (is_intermediary_file) {
		ci = fvars.ci;
	}

	// Get character type.
	let ctype = char && Number(char) ? "number" : "character";

	// Replace whitespace characters with their respective symbols.
	char = char.replace(/ /g, "␣").replace(/\t/g, "⇥");

	// Add syntax highlight.
	char = h(char, "value");
	name = h(name, name.startsWith("@") ? "setting" : "flag");

	// Parsing error reasons.
	let reasons = {
		"p.setting.js": {
			// 0: "Unexpected token '@'.",
			1: `Setting started with '${char}'. Expected a letter.`,
			2: `Unexpected ${ctype}: '${char}'.`,
			3: `Value cannot start with '${char}'.`,
			4: `Improperly quoted string.`,
			// Parsing warning reasons.
			5: `Unescaped ${ctype}: '${char}' in value.`,
			6: `Empty setting assignment.`,
			7: `Duplicate setting: '${name}'.`,
			8: `Empty setting: '${name}'.`
		},
		"p.command.js": {
			1: `Chain started with: '${char}'. Expected a letter.`,
			2: `Unnecessary escape ${ctype}: ${h(
				"\\" + stripansi(char),
				"value"
			)}.`,
			3: `Illegal escape sequence: ${h(
				"\\" + stripansi(char),
				"value"
			)}.`,
			4: `Unexpected ${ctype}: '${char}'.`,
			// Parsing warning reasons.
			5: `Empty command chain assignment.`,
			6: `Empty '${h("[]", "value")}' (no flags).`,
			7: `Unclosed shortcut brace: '${char}'.`,
			8: `Illegal command delimiter: '${char}'.`,
			9: `Illegal shortcut delimiter: '${char}'.`
		},
		"p.flagset.js": {
			1: `Setting started with '${char}'. Expected a letter.`,
			2: `Unexpected ${ctype}: '${char}'.`,
			3: `Value cannot start with '${char}'.`,
			4: `Improperly quoted string.`,
			5: `Unescaped ${ctype} '${char}' in value.`,
			// Parsing warning reasons.
			// 6: `Empty flag assignment.`,
			8: `Empty flag: '${name}' (use boolean indicator: '${h(
				"?",
				"value"
			)}').`,
			9: `${
				isvspecial === "command" ? "Command-flag" : "Options flag list"
			} missing closing '${h(")", "value")}'.`,
			10: `Empty flag namespace '${char}'.`
		},
		"p.flag-command.js": {
			2: `Unexpected ${ctype}: '${char}'.`,
			3: `Value cannot start with: '${char}'.`,
			4: `Improperly quoted string.`,
			5: `Empty command flag argument.`,
			6: `Improperly closed command-flag. Missing '${h(")", "value")}'.`,
			11: `Empty string '${chalk.yellow(stripansi(char))}'.`
		},
		"p.flag-value.js": {
			2: `Unexpected ${ctype}: '${char}'.`,
			4: `Improperly quoted string.`,
			5: `Unescaped ${ctype}: '${char}' in value.`,
			10: `Empty '${h("()", "value")}' (no flag options).`,
			11: `Empty string '${chalk.yellow(stripansi(char))}'.`
		},
		"p.flagoption.js": {
			0: `Empty flag option.`,
			// 2: `Unexpected ${ctype}: '${char}'.`,
			3: `Invalid flag option.`,
			4: `Improperly quoted string.`
		},
		"p.close-brace.js": { 1: `Unexpected ${ctype}: '${char}'.` },
		"p.comment.js": {}
	};

	// Generate issue with provided information.
	return ((type = "error", code, char = "") => {
		// Calculate character index.
		let index = is_intermediary_file ? ci - line_fchar : i - line_fchar + 1; // Add 1 to account for 0 index.

		// Generate base issue object.
		let issue_object = {
			line: line_num,
			index,
			reason: reasons[scriptname][code],
			// Add key to denote file giving issue.
			source: scriptname
		};

		// Add additional information if issuing an error and return.
		if (type === "error") {
			return Object.assign(issue_object, {
				char,
				code,
				state,
				warnings,
				// Add key to denote file giving issue.
				source: scriptname
			});
		} else {
			// Add warning to warnings array.
			warnings.push(issue_object);
		}

		// Return issue object.
		return issue_object;
	})(type, code, char);
};
