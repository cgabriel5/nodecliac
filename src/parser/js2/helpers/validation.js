#!/usr/bin/env node

"use strict";

const xregexp = require("xregexp");

const { hasProp } = require("../utils/toolbox.js");
const { issue_hint, issue_warn, issue_error } = require("./issue.js");

function vsetting(S) {
	let token = S.lexerdata.tokens[S.tid];
	let start = token.start;
	let end = token.end;
	let line = token.line;
	let index = token.start;

	const settings = ["compopt", "filedir", "disable", "placehold", "test"];

	let setting = S.text.substring(start + 1, end + 1);

	// Warn if setting is not a supported setting.
	if (!settings.includes(setting)) {
		let message = "Unknown setting: '" + setting + "'";

		if (!hasProp(S.warnings, line)) {
			S.warnings[line] = [];
		}
		S.warnings[line].push([S.filename, line, index - S.lexerdata.LINESTARTS[line], message]);
		S.warn_lines.add(line);
	}
}

function isdigit(s) {
	if (s === "") return false;
	return xregexp("^[\\p{Nd}]+$").test(s);
}

function vvariable(S) {
	let token = S.lexerdata.tokens[S.tid];
	let start = token.start;
	let end = token.end;
	let line = token.line;
	let index = token.start;

	// Error when variable starts with a number.
	if (isdigit(S.text[start + 1])) {
		let message = "Unexpected: '" + S.text[start + 1] + "'";
		message += "\n\u001b[1;36mInfo\u001b[0m: Variable cannot begin with a number.";
		issue_error(S.filename, line, index - S.lexerdata.LINESTARTS[line], message);
	}
}

function vstring(S) {
	let token = S.lexerdata.tokens[S.tid];
	let start = token.start;
	let end = token.end;
	let line = token.lines[0];
	let index = token.start;

	// Warn when string is empty.
	// [TODO] Warn if string content is just whitespace?
	if (end - start == 1) {
		let message = "Empty string";

		if (!hasProp(S.warnings, line)) {
			S.warnings[line] = [];
		}
		S.warnings[line].push([S.filename, line, index - S.lexerdata.LINESTARTS[line], message]);
		S.warn_lines.add(line);
	}

	// Error if string is unclosed.
	if (token.lines[1] == -1) {
		let message = "Unclosed string";
		issue_error(S.filename, line, index - S.lexerdata.LINESTARTS[line], message);
	}
}

function vsetting_aval(S) {
	let token = S.lexerdata.tokens[S.tid];
	let start = token.start;
	let end = token.end;
	let line = token.line;
	let index = token.start;

	let values = ["true", "false"];

	let value = S.text.substring(start, end + 1);

	// Warn if values is not a supported values.
	if (!values.includes(value)) {
		let message = "Invalid setting value: '" + value + "'";
		issue_error(S.filename, line, index - S.lexerdata.LINESTARTS[line], message);
	}
}

module.exports = { vsetting, vvariable, vstring, vsetting_aval };
