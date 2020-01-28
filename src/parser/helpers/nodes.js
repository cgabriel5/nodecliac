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
		startpoint: S.i,
		endpoint: null
	};

	// Modify each type as needed.
	switch (type) {
		case "COMMENT":
			N.sigil = { start: null, end: null };
			N.comment = { start: null, end: null, value: "" };

			break;

		case "NEWLINE":
			N.sigil = { start: null, end: null };

			break;

		case "SETTING":
			N.sigil = { start: null, end: null };
			N.name = { start: null, end: null, value: "" };
			N.assignment = { start: null, end: null, value: null };
			N.value = { start: null, end: null, value: null };

			break;

		case "VARIABLE":
			N.sigil = { start: null, end: null };
			N.name = { start: null, end: null, value: "" };
			N.assignment = { start: null, end: null, value: null };
			N.value = { start: null, end: null, value: null };

			break;

		case "COMMAND":
			N.sigil = { start: null, end: null };
			N.command = { start: null, end: null, value: "" };
			N.name = { start: null, end: null, value: "" };
			N.brackets = { start: null, end: null, value: null };
			N.assignment = { start: null, end: null, value: null };
			N.delimiter = { start: null, end: null, value: null };
			N.value = { start: null, end: null, value: null };
			N.flags = [];

			break;

		case "FLAG":
			N.hyphens = { start: null, end: null, value: null };
			N.variable = { start: null, end: null, value: null };
			N.name = { start: null, end: null, value: null };
			N.boolean = { start: null, end: null, value: null };
			N.assignment = { start: null, end: null, value: null };
			N.multi = { start: null, end: null, value: null };
			N.brackets = { start: null, end: null, value: null };
			N.value = { start: null, end: null, value: null, type: null };
			N.keyword = { start: null, end: null, value: null };

			break;

		case "OPTION":
			N.bullet = { start: null, end: null, value: null };
			N.value = { start: null, end: null, value: null, type: null };

			break;

		case "BRACE":
			N.brace = { start: null, end: null, value: null };

			break;
	}

	return N;
};
