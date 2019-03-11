/**
 * Create a lookup table to remove duplicate command chains. Duplicate
 *     chains will have all their respective flag sets combined as well.
 *
 * @param  {string} commandchain - The line's command chain.
 * @param  {string} flags - The line's flag set.
 * @return {undefined} - Nothing is returned.
 */

module.exports = (commandchain, flags, lookup) => {
	// // Check if command chain contains invalid characters.
	// let r = /[^-._:a-zA-Z0-9\\/]/;
	// if (r.test(commandchain)) {
	// 	// Loop over command chain to highlight invalid character.
	// 	let chars = [];
	// 	let invalid_char_count = 0;
	// 	for (let i = 0, l = commandchain.length; i < l; i++) {
	// 		// Cache current loop item.
	// 		let char = commandchain[i];

	// 		// If an invalid character highlight.
	// 		if (r.test(char)) {
	// 			chars.push(chalk.bold.red(char));
	// 			invalid_char_count++;
	// 		} else {
	// 			chars.push(char);
	// 		}
	// 	}

	// 	// Plural output character string.
	// 	let char_string = `character${invalid_char_count > 1 ? "s" : ""}`;

	// 	// Invalid escaped command-flag found.
	// 	exit([
	// 		`${chalk.bold(
	// 			"Invalid:"
	// 		)} ${char_string} in command: ${chars.join("")}`,
	// 		`Remove invalid ${char_string} to successfully parse acmap file.`
	// 	]);
	// }
	// // Command must start with letters.
	// if (!/^\w/.test(commandchain)) {
	// 	exit([
	// 		`${chalk.bold(
	// 			"Invalid:"
	// 		)} command '${commandchain}' must start with a letter.`,
	// 		`Fix issue to successfully parse acmap file.`
	// 	]);
	// }

	// Normalize command chain. Replace unescaped '/' with '.' dots.
	commandchain = commandchain.replace(/([^\\]|^)\//g, "$1.");

	// Note: Create needed parent commandchain(s). For example, if the
	// current commandchain is 'a.b.c' we create the chains: 'a.b' and
	// 'a' if they do not exist. Kind of like 'mkdir -p'.
	// Parse command chain for individual commands.
	let cparts = [];
	let command = "";
	let command_string = "";
	let command_count = 0;
	for (let i = 0, l = commandchain.length; i < l; i++) {
		// Cache current loop characters.
		let char = commandchain.charAt(i);
		let pchar = commandchain.charAt(i - 1);
		let nchar = commandchain.charAt(i + 1);

		// If a dot or slash and it's not escaped.
		if (/(\.|\/)/.test(char) && pchar !== "\\") {
			// Push current command to parts array.
			cparts.push(command);

			// Track command path.
			command_string += command_count ? `.${command}` : command;
			// Add command path to lookup.
			if (!lookup[command_string]) {
				lookup[command_string] = [];
			}

			// Clear current command.
			command = "";
			command_count++;
			continue;
		} else if (char === "\\" && /(\.|\/)/.test(nchar)) {
			// Add separator to current command since it's used as
			// an escape sequence.
			command += `\\${nchar}`;
			i++;
			continue;
		}

		// Append current char to current command string.
		command += char;
	}
	// // Add remaining command if string is not empty.
	// if (command) { cparts.push(command); }

	// Store in lookup table.
	if (!lookup[commandchain]) {
		lookup[commandchain] = [flags];
	} else {
		lookup[commandchain].push(flags);
	}
};
