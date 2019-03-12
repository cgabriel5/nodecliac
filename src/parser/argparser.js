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
module.exports = input => {
	// Vars.
	let current = "";
	let quote_char = "";
	let args = [];

	// Vars - Flags.
	let isquoted = false;
	let iscommandflag = false;

	// Return empty array when input is empty.
	if (!input || !input.length) {
		return args;
	}

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
				current += c;
				quote_char = c;

				// Set flag: open quote.
				isquoted = true;
			}
		}
		// Append all other characters to current string.
		else {
			current += c;
		}
	}

	// Add the remaining word.
	if (current) {
		args.push(current);
	}

	// Return parsed arguments list.
	return args;
};
