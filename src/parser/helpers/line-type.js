"use strict";

const { r_space, r_letter } = require("./patterns.js");

/**
 * Determine line's line type.
 *
 * @param  {object} S - State object.
 * @param  {string} char - The loop's current character.
 * @param  {string} nchar - The loop's next character.
 * @return {string} - The line's type.
 */
module.exports = (S, char, nchar) => {
	let { text } = S;

	let LINE_TYPES = {
		";": "terminator", // Terminator (end parsing).
		"#": "comment",
		$: "variable",
		"@": "setting",
		"-": "flag",
		")": "close-brace",
		"]": "close-brace"
	};

	let line_type = LINE_TYPES[char];

	//  Line type overrides for: command, option, default.

	if (!line_type && r_letter.test(char)) line_type = "command";
	if (line_type === "flag") {
		if (nchar && r_space.test(nchar)) line_type = "option";
	} else if (line_type === "command") {
		if (text.substr(S.i, 7) === "default") line_type = "flag";
	}

	return line_type;
};
