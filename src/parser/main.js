"use strict";

module.exports = (
	string,
	commandname,
	source,
	formatting,
	highlight,
	trace,
	nowarn,
	stripcomments
) => {
	// Vars - timers.
	let stime = process.hrtime(); // Store start time tuple array.

	// RegEx patterns
	let r_letter = /[a-zA-Z]/; // Letter.
	let r_start_line_char = /[-@a-zA-Z)\]$#]/; // Valid starting line characters.

	// Possible line types lookup table.
	const LINE_TYPES = {
		// ".": "command",
		"#": "comment",
		"@": "setting",
		$: "variable",
		"]": "close-bracket",
		"-": "close-parenthesis"
	};

	const PARSERS = {
		command: require("./parser.command.js"),
		comment: require("./parser.comment.js"),
		setting: require("./parser.setting.js"),
		variable: require("./parser.variable.js")
		// "close-bracket": function() {},
		// "close-parenthesis": function() {},
	};

	// Loop global state variables.
	const STATE = {
		line: 1,
		column: 0,
		i: 0,
		l: string.length,
		string
	};
	// Loop local vars.
	let first_non_whitespace_char = "";
	let line_type = "";

	// Loop over acdef file contents to parse.
	for (; STATE.i < STATE.l; STATE.i++) {
		// Cache current loop item.
		let char = string.charAt(STATE.i);

		if (char === "\n") {
			STATE.line++; // Increment line count.
			STATE.column = 0; // Reset column to zero.
			first_non_whitespace_char = "";

			// Skip iteration at this point.
			continue;
		}

		STATE.column++; // Increment column position.

		// Find first non-whitespace character of line.
		if (!first_non_whitespace_char && !/[ \t]/.test(char)) {
			first_non_whitespace_char = char; // Set flag.

			// Line must start w/ a start-of-line character.
			// Or else line is invalid so give stop parsing
			// and give error.
			// +---------------------------------------------+
			// | Character |  Line-Type                      |
			// | --------------------------------------------|
			// | @         |  Setting.                       |
			// | #         |  Comment.                       |
			// | a-zA-Z    |  Command chain.                 |
			// | -         |  Flag.                          |
			// | '- '      |  Flag option (ignore quotes).   |
			// | )         |  Closing flag set.              |
			// | ]         |  Closing long-flag form.        |
			// +---------------------------------------------+
			if (!r_start_line_char.test(char)) {
				// Error as first lien character is now allowed.
				console.log(
					"char it not allowed",
					`line:${STATE.line}, column:${STATE.column}`
				);
				console.log(r_start_line_char, char);
				process.exit();
			}

			// Note: Reduce column counter by 1 since parser loop will
			// commence at the start of the first non whitespace char.
			// A char that has already been looped over in the main loop.
			STATE.column--;

			// Get the line type.
			line_type = LINE_TYPES[char];
			if (!line_type && /[a-zA-Z]/.test(char)) {
				line_type = "command";
			}
			// Run the line type's function.
			if (PARSERS[line_type]) {
				PARSERS[line_type](STATE);
			}
		}
	}

	let time = process.hrtime(stime);
	const duration = ((time[0] * 1e3 + time[1] / 1e6) / 1e3).toFixed(3);
	// console.log(process.hrtime(stime));
	console.log(duration);
	process.exit();
};
