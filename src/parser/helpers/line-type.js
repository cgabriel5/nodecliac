"use strict";

const { cin, C_SPACES, C_LETTERS, C_KW_ALL } = require("./charsets.js");

/**
 * Determine line's line type.
 *
 * @param  {object} S - State object.
 * @param  {char} char - The loop's current character.
 * @param  {char} nchar - The loop's next character.
 * @return {string} - The line's type.
 */
module.exports = (S, char, nchar) => {
	let { text } = S;

	let types = {
		";": "terminator", // End parsing.
		"#": "comment",
		$: "variable",
		"@": "setting",
		"-": "flag",
		")": "close-brace",
		"]": "close-brace"
	};

	let line_type = types[char];

	// Line type overrides for: command, option, default.
	if (!line_type && cin(C_LETTERS, char)) line_type = "command";
	if (line_type === "flag") {
		if (nchar && cin(C_SPACES, nchar)) line_type = "option";
	} else if (line_type === "command") {
		let keyword = text.substr(S.i, 7);
		if (-~C_KW_ALL.indexOf(keyword)) line_type = "flag";
	}

	return line_type;
};
