"use strict";

const { r_whitespace, r_letter } = require("./patterns.js");

/**
 * Determine line's line type.
 *
 * @param  {object} STATE - Main loop state object.
 * @param  {string} char - The loop's current character.
 * @param  {string} nchar - The loop's next character.
 * @return {string} - The line's type.
 */
module.exports = (STATE, char, nchar) => {
	let { string, utils } = STATE; // Loop state vars.

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
		if (nchar && r_whitespace.test(nchar)) line_type = "option";
		else STATE.singletonflag = true; // Make flag parser add node to tree.
	} else if (line_type === "command") {
		// Check for 'default' keyword.
		if (string.substr(STATE.i, 7) === "default") {
			line_type = "flag";
			STATE.singletonflag = true; // Make flag parser add node to tree.
		}
	}

	return line_type;
};
