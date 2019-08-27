"use strict";

// Get needed modules.
let { r_letter, r_whitespace } = require("./patterns.js");

/**
 * Determine the line's line type.
 *
 * @param  {object} STATE - Main loop state object.
 * @param  {string} char - The loop's current character.
 * @param  {string} nchar - The loop's next character.
 * @return {string} - The line's type.
 */
module.exports = (STATE, char, nchar) => {
	// Vars.
	let string = STATE.string;

	// Possible line types lookup table.
	// +----------------------------------------------+
	// | Character |  Line-Type                       |
	// | ---------------------------------------------|
	// | ;         |  Terminator (end parsing).       |
	// | @         |  Setting.                        |
	// | #         |  Comment.                        |
	// | a-zA-Z    |  Command chain.                  |
	// | -         |  Flag.                           |
	// | '- '      |  Flag option (ignore quotes).    |
	// | )         |  Closing brace (flag set).       |
	// | ]         |  Closing brace (long-flag form). |
	// +----------------------------------------------+
	let LINE_TYPES = {
		";": "terminator",
		"#": "comment",
		"-": "flag",
		"@": "setting",
		$: "variable",
		"]": "close-brace",
		")": "close-brace"
	};

	// Get the line type.
	let line_type = LINE_TYPES[char];

	// If line type doesn't exist default to command.
	if (r_letter.test(char)) {
		line_type = "command";
	}
	if (line_type === "flag") {
		// Check if a flag value.
		if (nchar && r_whitespace.test(nchar)) {
			// The line is actually a flag option so reset parser.
			line_type = "option";
		} else {
			// Note: (Set flag) This is needed to let flag parser
			// know to add the parsed Node to the parsing tree.
			STATE.singletonflag = true;
		}
	} else if (line_type === "command") {
		// Check for 'default' keyword.
		if (string.substr(STATE.i, 7) === "default") {
			line_type = "flag";

			// Note: (Set flag) This is needed to let flag parser
			// know to add the parsed Node to the parsing tree.
			STATE.singletonflag = true;
		}
	}

	return line_type;
};
