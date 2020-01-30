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
	let N = {
		node: type,
		line: S.line,
		start: S.i,
		end: -1
	};

	/**
	 * Creates Node.value object.
	 *
	 * @return {object} The Node.value object.
	 */
	let o = () => ({ start: -1, end: -1, value: "" });

	// Modify each type as needed.
	switch (type) {
		case "COMMENT":
			N.comment = o();

			break;

		case "NEWLINE":
			break;

		case "SETTING":
			N.sigil = o();
			N.name = o();
			N.assignment = o();
			N.value = o();
			N.args = [];

			break;

		case "VARIABLE":
			N.sigil = o();
			N.name = o();
			N.assignment = o();
			N.value = o();
			N.args = [];

			break;

		case "COMMAND":
			N.command = o();
			N.name = o();
			N.brackets = o();
			N.assignment = o();
			N.delimiter = o();
			N.value = o();
			N.flags = [];

			break;

		case "FLAG":
			N.hyphens = o();
			N.variable = o();
			N.name = o();
			N.boolean = o();
			N.assignment = o();
			N.multi = o();
			N.brackets = o();
			N.value = o();
			N.keyword = o();
			N.singleton = false;
			N.args = [];

			break;

		case "OPTION":
			N.bullet = o();
			N.value = o();
			N.args = [];

			break;

		case "BRACE":
			N.brace = o();

			break;
	}

	return N;
};
