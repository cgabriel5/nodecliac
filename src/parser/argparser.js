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

	// Return empty array when input is empty.
	if (!input || !input.length) {
		return args;
	}

	// Loop over every input char.
	for (let i = 0, l = input.length; i < l; i++) {
		// Cache current/previous/next chars.
		let c = input.charAt(i);
		let p = input.charAt(i - 1);
		// let n = input.charAt(i + 1);

		// Reset prev word for 1st char as bash gets the last char.
		if (i === 0) {
			p = "";
		}
		// else if (i === l - 1) {
		// 	// Reset next word for last char as bash gets the first char.
		// 	n = "";
		// }

		// If char is a space.
		if (c === " " && p !== "\\") {
			if (quote_char.length !== 0) {
				current += c;
			} else {
				if (current !== "") {
					args.push(current);
					current = "";
				}
			}
			// Non space chars.
		} else if ((c === '"' || c === "'") && p !== "\\") {
			if (quote_char !== "") {
				if (quote_char === c) {
					current += c;
					args.push(current);
					quote_char = "";
					current = "";
				} else {
					current += c;
					quote_char = c;
				}
			} else {
				current += c;
				quote_char = c;
			}
		} else {
			current += c;
		}
	}

	// Add the remaining word.
	if (current !== "") {
		args.push(current);
	}

	return args;
};
