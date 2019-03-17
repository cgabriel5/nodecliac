/**
 * Parse string command flag ($("")) arguments. This is done to basically
 *     to make command-flags uniform. For example, user can space out
 *     arguments. This will ensure that all space around arguments is
 *     effectively removed.
 *
 * @param  {string} input - The string command-flag to parse.
 * @return {string} - The cleaned command-flag string.
 */
module.exports = input => {
	// Parse command string to get individual arguments. Things to note:
	// each argument is to be encapsulated with strings. User can decide
	// which to use, either single or double. As long as their contents
	// are properly escaped.
	let args = [];
	let argument = "";
	let state = "closed";
	let quote_type = "";
	// let args_count = 0;

	// Return empty string when input is empty.
	if (!input || !input.length) {
		return '$("")';
	}

	// Remove '$()' syntax.
	input = input.replace(/^\$\(|\)$/g, "").trim();

	// Check for trailing comma (empty argument).
	if (/,$/.test(input)) {
		return {
			char: ",",
			pos: input.length - 1
		};
	}

	// Command flag syntax:
	// $("COMMAND-STRING" [, [<ARG1>, <ARGN> [, "<DELIMITER>"]]])

	// Loop over every input char.
	for (let i = 0, l = input.length; i < l; i++) {
		// Cache current/previous/next chars.
		let char = input.charAt(i);
		let pchar = input.charAt(i - 1);
		let nchar = input.charAt(i + 1);

		// If char is an unescaped quote.
		if (/["']/.test(char) && pchar !== "\\" && state === "closed") {
			// Check if the previous character is a dollar sign. This
			// means the command should run as a command.
			if (pchar && pchar === "$") {
				argument += "$";
			}
			// Set state to open.
			state = "open";
			// Set quote type.
			quote_type = char;
			// Store the character.
			argument += char;
		} else if (
			// If char is an unescaped quote + status is open...reset.
			/["']/.test(char) &&
			pchar !== "\\" &&
			state === "open" &&
			quote_type === char
		) {
			// Set state to close.
			state = "closed";
			// Reset quote type.
			quote_type = "";
			// Store the character.
			argument += char;
		} else if (char === "\\") {
			// Handle escaped characters.
			if (nchar) {
				// Store the character.
				argument += `${char}${nchar}`;
				i++;
			} else {
				// Store the character.
				argument += char;
			}
		} else if (!/["']/.test(char)) {
			// For anything that is not a quote char.

			// If we hit a comma and the state is closed. We store the
			// current argument and reset everything.
			if (state === "closed") {
				if (char === ",") {
					args.push(argument);

					// If arg is empty return an error.
					if (!argument) {
						return {
							char,
							pos: i
						};
					}

					// args_count++;
					argument = "";
				} else {
					// The only allowed characters when not in a closed
					// state are spaced/tabs (whitespace), ans commas (,).
					// Any other character is not allowed and should cause
					// an error.
					if (!/[ \t,]/.test(char)) {
						return {
							// Return offending character and its index.
							char,
							pos: i
						};
					}
				}
			} else if (state === "open") {
				// Store the character. Any characters are allowed as long
				// as its quoted. Any characters with special meaning must
				// be properly escaped.
				argument += char;
			}
		}
	}
	// Add remaining argument if string is not empty.
	if (argument) {
		args.push(argument);

		// If arg is empty return an error.
		if (!argument) {
			return {
				char,
				pos: i
			};
		}

		// args_count++;
	}

	// Return cleaned arguments string.
	return `$(${args.join(",")})`;
};
