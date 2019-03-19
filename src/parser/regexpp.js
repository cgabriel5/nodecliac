/**
 * Export used RegExp patterns.
 */
module.exports = {
	// Letter.
	r_letter: /[a-zA-Z]/,
	// Whitespace.
	r_whitespace: /[ \t]/,
	// New line character.
	r_nl: new RegExp(`(\\r?\\n)`),
	// Open command bracket.
	r_open_command_br: /^\[\]?$/,
	// Close bracket.
	r_close_br: /^[ \t]*\][ \t]*$/,
	// Close parentheses.
	r_close_parens: /^[ \t]*\)[ \t]*$/,
	// Starting line character.
	r_start_line_char: /[-@a-zA-Z\)\]#]/,
	// Command setter.
	r_command_setter: /^[ \t]*=[ \t]*(\[|-{1,2})/,
	// Flag option.
	r_flag_option: /^[ \t]*-[ \t]{1,}([^\s]{1,}.*?)$/,
	// Command.
	r_command: new RegExp(`[-_.:a-zA-Z0-9\\\\\/{}\|]`),
	// Unquoted special characters: [https://stackoverflow.com/a/44581064]
	r_schars: /(?<!\\)[~`!#\$\^&\*(){}\|\[\];'",<>\? ]/,
	// Setting syntax.
	r_setting: /^(@[a-zA-Z][_a-zA-Z]*)[ \t]*(=[ \t]*(.*?))?$/,
	// Flag set.
	r_flag_set: /^(-{1,2})([a-zA-Z][-._:a-zA-Z0-9]*)[ \t]*((=\*?)[ \t]*(\(|\(\)|.*?)?)?$/
};
