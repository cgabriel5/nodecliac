"use strict";

const { r_space, r_letter } = require("./patterns.js");

/**
 * Determine line's line type.
 *
 * @param  {object} S - Main loop state object.
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
		// "a-zA-Z": "chain",
		"-": "flag",
		// "- ": "flag-option",
		")": "close-brace",
		"]": "close-brace"
	};

	let line_type = LINE_TYPES[char]; // Lookup line type.

	// If line type is undefined check for command characters.
	if (!line_type && r_letter.test(char)) line_type = "command";

	// Perform final line type overrides/variable resets.
	if (line_type === "flag") {
		// Line is actually a flag option so reset parser.
		if (nchar && r_space.test(nchar)) line_type = "option";
	} else if (line_type === "command") {
		// Check for 'default' keyword.
		if (text.substr(S.i, 7) === "default") {
			line_type = "flag";
		}
	}

	return line_type;
};
