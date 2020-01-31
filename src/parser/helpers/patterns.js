"use strict";

module.exports = {
	r_quote: /["']/, // Quotes.
	r_letter: /[a-zA-Z]/, // Letters.
	r_space: /[ \t]/, // Whitespace.
	r_nl: new RegExp(`(\\r?\\n)`), // Newlines.
	r_sol_char: /[-@a-zA-Z)\]$;#]/ // Start-of-line characters.

	// r_nlpipe: new RegExp(`(\\r?\\n|\\|)`), // Pipe oneliner delimiter.
	// r_open_command_br: /^\[\]?$/, // Open command bracket.
	// r_close_br: /^[ \t]*\][ \t]*$/, // Close bracket.
	// r_close_parens: /^[ \t]*\)[ \t]*$/, // Close parentheses.
	// r_command_setter: /^[ \t]*=[ \t]*(\[|-{1,2})/, // Command setter.
	// r_flag_option: /^[ \t]*-[ \t]{1,}([^\s]{1,}.*?)$/, // Flag option.
	// r_command: new RegExp(`[-_.:a-zA-Z0-9\\\\/{}|]`), // Command.
	// Unquoted special characters: [https://stackoverflow.com/a/44581064]
	// [https://mywiki.wooledge.org/BashGuide/SpecialCharacters]
	// r_schars: /(?<!\\)[~`!#$^&*(){}|[\];'",<>? ]/,
	// r_setting: /^(@[a-zA-Z][_a-zA-Z]*)[ \t]*(=[ \t]*(.*?))?$/, // Setting syntax.
	// r_number: /^(?:NaN|-?(?:(?:\d+|\d*\.\d+)(?:[E|e][+|-]?\d+)?|Infinity))$/, // Number pattern: [https://stackoverflow.com/a/30987109]
	// r_flag_set: /^(-{1,2})([a-zA-Z][-._:a-zA-Z0-9]*)[ \t]*((=\*?)[ \t]*(\(|\(\)|.*?)?)?$/ // Flag set.
};
