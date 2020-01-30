"use strict";

// Loop state object.
module.exports = (action, text, source, fmt, trace, igc, test) => {
	return {
		line: 1,
		column: 1,
		i: 0,
		l: text.length,
		text,
		specificity: 0, // Default to allow anything initially.
		sol_char: "", // First non-whitespace char of line.
		scopes: { command: null, flag: null }, // Track command/flag scopes.

		// Parsing lookup tables.
		tables: { variables: {}, linestarts: {}, tree: { nodes: [] } },

		// Arguments/parameters for quick access across parsers.
		args: { action, source, fmt, trace, igc, test }
	};
};
