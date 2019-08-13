"use strict";

// Get needed modules.
let issue = require("./helper.issue.js");

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
		";": "eof",
		// ".": "command",
		"#": "comment",
		"-": "flag",
		"@": "setting",
		$: "variable",
		"]": "close-brace",
		")": "close-brace",
		_: "empty-line"
	};

	// Note: [Hierarchy lookup table] The lower the number the higher its
	// precedence, therefore: command > flag > option. Variables, settings,
	// and command chains have the same precedence as they are same-level
	// defined (cannot be nested). Comments can be placed anywhere so
	// they don't have a listed precedence.
	const SPECIFICITIES = {
		setting: 5,
		variable: 4,
		command: 3,
		flag: 2,
		option: 1,
		comment: 0
	};

	const PARSERS = {
		command: require("./parser.command.js"),
		comment: require("./parser.comment.js"),
		setting: require("./parser.setting.js"),
		variable: require("./parser.variable.js"),
		flag: require("./parser.flag.js"),
		option: require("./parser.option.js"),
		"close-brace": require("./parser.close-brace.js"),
		"empty-line": require("./parser.empty-line.js")
	};

	// Parsing database.
	const DB = {
		variables: {}, // Contain variable_name:value pairs.
		linestarts: {}, // Contain line index start points.
		table: {}, // Contain command-chains/flag sets.
		tree: {} // Line by line parsed tree nodes.
	};

	// Loop global state variables.
	const STATE = {
		line: 1,
		column: 0,
		i: 0,
		l: string.length,
		string,
		// Attach database to access across parsers.
		DB,
		//
		SPECIFICITIES,
		specificity: 0, // Default to allow anything.
		// Have quick access to the last parsed command-chain/flag.
		lastcc: null,
		lastflag: null,
		scopes: {
			command: null,
			flag: null
		}
	};
	// Loop local vars.
	let first_non_whitespace_char = "";
	let line_type = "";

	// Loop over acdef file contents to parse.
	for (; STATE.i < STATE.l; STATE.i++) {
		// Cache current loop item.
		let char = string.charAt(STATE.i);
		let nchar = string.charAt(STATE.i + 1);

		if (char === "\n") {
			// Run empty line parser.
			PARSERS["empty-line"](STATE);

			STATE.line++; // Increment line count.
			STATE.column = 0; // Reset column to zero.
			first_non_whitespace_char = "";

			// Skip iteration at this point.
			continue;
		}

		STATE.column++; // Increment column position.
		// Store startpoint.
		if (!DB.linestarts[STATE.line]) {
			DB.linestarts[STATE.line] = STATE.i;
		}

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
				console.log("TREE", STATE.DB.tree);
				// Error as first lien character is now allowed.
				// console.log(`INVALID_CHAR << ${STATE.line}:${STATE.column}`);
				// Don't issue warning for ';' parsing terminator.
				if (char !== ";") {
					issue.error(STATE, 0, __filename);
				}
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

			if (line_type === "eof") {
				break;
			}

			if (line_type === "flag") {
				// Check if a flag value.
				if (nchar && /[ \t]/.test(nchar)) {
					// The line is actually a flag option so reset parser.
					line_type = "option";
				} else {
					STATE.singleton = true;
				}
			}

			// Get line specificity and store value.
			// let old_specificity = STATE.specificity;
			let line_specificity = SPECIFICITIES[line_type] || 0;

			// However, if we are in a scope then the scope's specificity
			// trumps the line specificity.
			let state_specificity = STATE.scopes.flag
				? SPECIFICITIES.flag
				: STATE.scopes.command
				? SPECIFICITIES.command
				: STATE.specificity;

			// Note: Check whether specificity hierarchy is allowed.
			if (state_specificity && state_specificity <= line_specificity) {
				issue.error(STATE, 0, __filename);
			}
			// Set state specificity.
			state_specificity = line_specificity;

			// Run the line type's function.
			if (PARSERS[line_type]) {
				PARSERS[line_type](STATE);
			}
		}
	}

	// Note: If a command-chain scope still exists after parsing then a scope
	// was never closed so give an error.
	require("./helper.brace-checks.js")(STATE, null, "post-standing-scope");

	let time = process.hrtime(stime);
	const duration = ((time[0] * 1e3 + time[1] / 1e6) / 1e3).toFixed(3);
	// console.log(process.hrtime(stime));
	console.log(duration);
	process.exit();
};
