"use strict";

const { cin, C_SPACES, C_KW_ALL, C_CMD_IDENT_START } = require("./charsets.js");

/**
 * Determine line's line type.
 *
 * @param  {object} S - State object.
 * @param  {char} c - The loop's current character.
 * @param  {char} n - The loop's next character.
 * @return {string} - The line's type.
 */
module.exports = (S, c, n) => {
	let types = {
		";": "terminator", // End parsing.
		"#": "comment",
		$: "variable",
		"@": "setting",
		"-": "flag",
		")": "close-brace",
		"]": "close-brace"
	};

	let line_type = types[c];

	// Line type overrides for: command, option, default.
	if (!line_type && cin(C_CMD_IDENT_START, c)) line_type = "command";
	if (line_type === "flag") {
		if (n && cin(C_SPACES, n)) line_type = "option";
	} else if (line_type === "command") {
		let keyword = S.text.substr(S.i, 7);
		if (-~C_KW_ALL.indexOf(keyword)) line_type = "flag";
	}

	return line_type;
};
