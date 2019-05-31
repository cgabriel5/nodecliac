"use strict";

// Get needed modules.
const path = require("path");
const chalk = require("chalk");

module.exports = (...args) => {
	// Get arguments.
	let [i, filename, warnings, state, type, code, fvars = {}] = args;

	// Get globals
	let string = global.$app.get("string");
	let l = global.$app.get("l");
	let line_num = global.$app.get("line_num");
	let line_fchar = global.$app.get("line_fchar");
	let h = global.$app.get("highlighter");
	let s = global.$app.get("stripansi");

	// Get basename from file name.
	let scriptname = path.basename(filename);
	// Check if file is an intermediary file.
	let is_intermediary_file = /^p\.flag-(command|value)\.js$/.test(scriptname);

	// Define variables for specific parsers.
	let ci = fvars.ci || 0,
		char = fvars.char || "",
		flag = fvars.flag || "",
		name = fvars.name || "",
		isvspecial = fvars.isvspecial,
		chain = fvars.currentchain || "";

	// Get character type.
	let ctype = char && Number(char) ? "number" : "character";

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
			7: `Dupe setting: '${name}'.`,
			8: `Empty setting: '${name}'.`
		},
		"p.command.js": {
			1: `Chain started with: '${char}'. Expected a letter.`,
			2: `Unnecessary escape ${ctype}: ${h("\\" + s(char), "value")}.`,
			3: `Illegal escape sequence: ${h("\\" + s(char), "value")}.`,
			4: `Unexpected ${ctype}: '${char}'.`,
			// Parsing warning reasons.
			5: `Empty command chain assignment.`,
			6: `Empty '${h("[]", "value")}' (no flags).`,
			7: `Unclosed shortcut brace: '${char}'.`,
			8: `Illegal command delimiter: '${char}'.`,
			9: `Illegal shortcut delimiter: '${char}'.`,
			10: `Dupe command: '${h(s(name), "command")}'.`
		},
		"p.flagset.js": {
			1: `Flag started with '${char}'. Expected a letter.`,
			2: `Unexpected ${ctype}: '${char}'.`,
			3: `Value cannot start with '${char}'.`,
			4: `Improperly quoted string.`,
			5: `Unescaped ${ctype} '${char}' in value.`,
			// Parsing warning reasons.
			// 6: `Empty flag assignment.`,
			8: `Empty flag: '${name}' (use bool mark: '${h("?", "value")}').`,
			9: `${
				isvspecial === "command" ? "Command-flag" : "Options flag list"
			} missing closing '${h(")", "value")}'.`,
			10: `Empty flag namespace '${char}'.`,
			11: `Dupe flag: '${name}'.`,
			12: `Dupe ${h("command-string", "keyword")} (${chain}).`,
			13: `Empty '${h(
				"command-string",
				"keyword"
			)}' value for command: '${chain}'.`
		},
		"p.flag-command.js": {
			2: `Unexpected ${ctype}: '${char}'.`,
			3: `Value cannot start with: '${char}'.`,
			4: `Improperly quoted string.`,
			5: `Empty command flag argument.`,
			6: `Improperly closed command-flag. Missing '${h(")", "value")}'.`,
			11: `Empty string '${chalk.yellow(s(char))}'.`
		},
		"p.flag-value.js": {
			2: `Unexpected ${ctype}: '${char}'.`,
			4: `Improperly quoted string.`,
			5: `Unescaped ${ctype}: '${char}' in value.`,
			10: `Empty '${h("()", "value")}' (no flag options).`,
			11: `Empty string '${chalk.yellow(s(char))}'.`,
			12: `Dupe value: '${char}' (${flag.replace(
				/^(-{1,2})(.*?)$/g,
				`$1${h("$2", "flag")}`
			)}).`
		},
		"p.flagoption.js": {
			0: `Empty flag option.`,
			2: `Unexpected ${ctype}: '${char}'.`,
			3: `Invalid flag option.`,
			4: `Improperly quoted string.`,
			5: `Dupe ${h("command-string", "keyword")} (${chain}).`,
			6: `Empty '${h(
				"command-string",
				"keyword"
			)}' value for command: '${chain}'.`
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
