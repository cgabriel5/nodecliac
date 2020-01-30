"use strict";

const path = require("path");
const chalk = require("chalk");

/**
 * Create parsing node object.
 *
 * @param  {object} S - The state object.
 * @param  {string} type - The object type to create.
 * @return {object} - The created node object.
 */
module.exports = (S, type) => {
	// Base object.
	let N = {
		node: type,
		line: S.line,
		start: S.i,
		end: -1
	};

	// Modify each type as needed.
	switch (type) {
		case "COMMENT":
			N.comment = { start: -1, end: -1, value: "" };

			break;

		case "NEWLINE":
			break;

		case "SETTING":
			N.sigil = { start: -1, end: -1 };
			N.name = { start: -1, end: -1, value: "" };
			N.assignment = { start: -1, end: -1, value: "" };
			N.value = { start: -1, end: -1, value: "" };

			break;

		case "VARIABLE":
			N.sigil = { start: -1, end: -1 };
			N.name = { start: -1, end: -1, value: "" };
			N.assignment = { start: -1, end: -1, value: "" };
			N.value = { start: -1, end: -1, value: "" };

			break;

		case "COMMAND":
			N.command = { start: -1, end: -1, value: "" };
			N.name = { start: -1, end: -1, value: "" };
			N.brackets = { start: -1, end: -1, value: "" };
			N.assignment = { start: -1, end: -1, value: "" };
			N.delimiter = { start: -1, end: -1, value: "" };
			N.value = { start: -1, end: -1, value: "" };
			N.flags = [];

			break;

		case "FLAG":
			N.hyphens = { start: -1, end: -1, value: "" };
			N.variable = { start: -1, end: -1, value: "" };
			N.name = { start: -1, end: -1, value: "" };
			N.boolean = { start: -1, end: -1, value: "" };
			N.assignment = { start: -1, end: -1, value: "" };
			N.multi = { start: -1, end: -1, value: "" };
			N.brackets = { start: -1, end: -1, value: "" };
			N.value = { start: -1, end: -1, value: "", type: null };
			N.keyword = { start: -1, end: -1, value: "" };

			break;

		case "OPTION":
			N.bullet = { start: -1, end: -1, value: "" };
			N.value = { start: -1, end: -1, value: "", type: null };

			break;

		case "BRACE":
			N.brace = { start: -1, end: -1, value: "" };

			break;
	}

	return N;
};
