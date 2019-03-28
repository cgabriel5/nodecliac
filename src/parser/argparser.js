"use strict";

/**
 * Parse string by spaces. Takes into account quotes strings with spaces.
 *     Making sure to ignore those spaces. Also respects escaped characters.
 *     Adapted from argsplit module.
 *
 * @param  {string} input - The string input to parse.
 * @return {array} - Array containing the parsed items.
 *
 * @resource [https://github.com/evanlucas/argsplit]
 * @resource - Other CLI input parsers:
 *     [https://github.com/elgs/splitargs]
 *     [https://github.com/vladimir-tikhonov/string-to-argv#readme]
 *     [https://github.com/astur/arrgv]
 *     [https://github.com/mccormicka/string-argv]
 *     [https://github.com/adarqui/argparser-js]
 */
module.exports = (input, flag, error, warning /*line_count*/) => {
	// Vars.
	let current = "";
	let quote_char = "";
	let args = [];

	// Vars - Flags.
	let isquoted = false;
	let iscommandflag = false;

	// RegExp patterns.
	// Unquoted special characters: [https://stackoverflow.com/a/44581064]
	let r_schars = /(?<!\\)[~`!#$^&*(){}|[\];'",<>? ]/;

	// Return empty array when input is empty.
	if (!input || !input.length) {
		return args;
	}

	/**
	 * Checks argument for unescaped special characters and produces a
	 *     warning if any are found.
	 *
	 * @param  {string} arg [description]
	 * @return {undefined} - Console warning if unescaped characters found.
	 */
	let has_special_chars = (arg /*n*/) => {
		// If arg is unquoted check for unescaped special characters.
		if (!/^("|')/.test(arg)) {
			// Check for special characters in argument.
			if (r_schars.test(arg)) {
				warning(
					`Flag '${flag}' argument option '${arg}' contains unescaped special characters.`
				);
			}
		}
	};

	// Loop over every input char.
	for (let i = 0, l = input.length; i < l; i++) {
		// Cache current/previous/next chars.
		let c = input.charAt(i);
		let p = input.charAt(i - 1);
		let n = input.charAt(i + 1);

		// If char is a '$' (and is unescaped) check if the next
		// char is a '('...
		if (!current && c === "$" && n === "(" && p !== "\\") {
			// Store command-flag opening syntax.
			current = "$(";
			iscommandflag = true;

			// Increment index to skip '(' since we already added it.
			i++;
			// Skip further loop logic.
			continue;
		}
		// If command flag is set, there is no actually quoted string,
		// and the current character is ')'...
		else if (iscommandflag && c === ")" && !isquoted) {
			// Warn if unescaped characters are found for command-flag strings?
			// has_special_chars(current);

			// Look ahead. The next character must be a space (argument
			// delimiter) or nothing (end-of-line). All else is invalid.
			if (n && !/ /.test(n)) {
				return {
					// Return offending character and its index.
					char: n,
					pos: i + 1,
					code: i === l - 1 ? "eol" : "delimiter"
				};
			}

			// Add command-flag closing syntax.
			current += ")";
			// Finally, store command-flag string.
			args.push(current);

			// Reset values/flags.
			current = "";
			quote_char = "";
			iscommandflag = false;
			// Skip further loop logic.
			continue;
		}

		// If char is a space.
		if (c === " " && p !== "\\") {
			// If quote char exists then we are still building a string
			// so the current space character is part of the string.
			if (quote_char) {
				// Ignore unquoted white space for command flags.
				if (iscommandflag && !isquoted) {
					continue;
				}

				current += c;
			}
			// When the quote char is not set then we are not building a
			// string the current space character is not part of any string
			// any can be ignored.
			else {
				// If not building a command flag string and string exists
				// store it and reset string value.
				if (!iscommandflag && current) {
					// Warn if unescaped characters are found.
					has_special_chars(current);

					args.push(current);
					current = "";
				}
			}
		}
		// If char is an unescaped quote.
		else if ((c === '"' || c === "'") && p !== "\\") {
			// If a quote char exists...
			if (quote_char) {
				// Store built string.
				if (!iscommandflag && quote_char === c) {
					current += c;

					// Warn if unescaped characters are found.
					has_special_chars(current);

					// Look ahead. The next character must be a space (argument
					// delimiter) or nothing (end-of-line). All else is invalid.
					if (n && !/ /.test(n)) {
						return {
							// Return offending character and its index.
							char: n,
							pos: i + 1,
							code: i === l - 1 ? "eol" : "delimiter"
						};
					}

					args.push(current);
					quote_char = "";
					current = "";
				}
				// Quoted string has been built.
				else {
					current += c;
					quote_char = c;

					// Set flag: close quote.
					isquoted = false;
				}
			}
			// Else set opening quote.
			else {
				// // There should not be a current string before starting
				// // a quoted string. For example:
				// // --flag=*(("cat $(\"somet)hing\")\"$HOME/fit\""))
				// // ---------^ is invalid.
				// if (current && !isquoted && !iscommandflag) {
				// 	return {
				// 		// Return offending character and its index.
				// 		char: p,
				// 		pos: i - 1,
				// 		code: "invalid"
				// 	};
				// }

				current += c;
				quote_char = c;

				// Set flag: open quote.
				isquoted = true;
			}
		}
		// Append all other characters to current string.
		else {
			// console.log(c, isquoted, iscommandflag);
			// // If both flags are not set we have an invalid character.
			// if (!isquoted && !iscommandflag && !/[ \t,]/.test(c)) {
			// 	return {
			// 		// Return offending character and its index.
			// 		char: c,
			// 		pos: i
			// 	};
			// }

			current += c;
		}
	}

	// Add the remaining word.
	if (current) {
		// Warn if unescaped characters are found.
		has_special_chars(current);

		args.push(current);
	}

	// Return parsed arguments list.
	return args;
};
