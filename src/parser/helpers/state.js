"use strict";

// State object.
module.exports = (action, cmdname, text, source, fmt, trace, igc, test) => {
	// Builtin variables.
	let platform = process.platform;
	if (platform === "darwin") platform = "macosx";
	if (platform === "win32") platform = "windows";
	let variables = {
		OS: platform,
		HOME: require("os").homedir(),
		COMMAND: cmdname,
		PATH: `~/.nodecliac/registry/${cmdname}`
	};

	return {
		line: 1,
		column: 1,
		i: 0,
		l: text.length,
		text,
		specf: 0, // Default to allow anything initially.
		sol_char: "", // First non-whitespace char of line.
		scopes: { command: null, flag: null }, // Track command/flag scopes.
		last_line_num: 0, // For tracing purposes.

		// Parsing lookup tables.
		tables: { variables, linestarts: {}, tree: { nodes: [] } },

		// Arguments/parameters for quick access across parsers.
		args: { action, source, fmt, trace, igc, test }
	};
};
