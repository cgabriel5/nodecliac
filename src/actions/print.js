"use strict";

// Needed modules.
const chalk = require("chalk");
const flatry = require("flatry");
const fe = require("file-exists");
const { exit, paths, read } = require("../utils/toolbox.js");

module.exports = async args => {
	// Get needed paths.
	let { registrypaths } = paths;
	// Get CLI args.
	let { command } = args;
	// Declare empty variables to reuse for all await operations.
	let err, res;

	// Source must be provided.
	if (!command) {
		exit([
			`Please provide a command name using the ${chalk.bold(
				"--command"
			)} flag.`
		]);
	}

	// If command is supplied then print its acdef/config file contents.
	if (command) {
		// Break apart command.
		let [, commandname = ""] = command.match(/^(.*?)(\.(acdef))?$/);
		let ext = ".acdef";

		// Exit and give error if a command name not provided.
		if (!commandname) {
			exit([
				`Please provide a command name (i.e. --command=${chalk.bold(
					"nodecliac.acdef"
				)}).`
			]);
		}

		// Check if command chain contains invalid characters.
		let r = /[^-._:a-zA-Z0-9\\/]/;
		if (r.test(commandname)) {
			// Loop over command chain to highlight invalid character.
			let chars = [];
			let invalid_char_count = 0;
			for (let i = 0, l = commandname.length; i < l; i++) {
				// Cache current loop item.
				let char = commandname[i];

				// If an invalid character highlight.
				if (r.test(char)) {
					chars.push(chalk.bold.red(char));
					invalid_char_count++;
				} else {
					chars.push(char);
				}
			}

			// Plural output character string.
			let char_string = `character${invalid_char_count > 1 ? "s" : ""}`;

			// Invalid escaped command-flag found.
			exit([
				`${chalk.bold(
					"Invalid:"
				)} ${char_string} in command: ${chars.join("")}`
			]);
		}

		// File paths.
		let filepath = `${registrypaths}/${commandname}/${commandname}${ext}`;
		let filepathconfig = `${registrypaths}/${commandname}/.${commandname}.config${ext}`;

		// Check if acdef file exists.
		[err, res] = await flatry(fe(filepath));

		// Print file contents.
		if (res) {
			[err, res] = await flatry(read(filepath));

			// Log file contents.
			console.log(`[${chalk.bold(`${commandname}${ext}`)}]\n`);
			console.log(res);

			// Check if config file exists.
			[err, res] = await flatry(fe(filepathconfig));
			// Print file contents.
			if (res) {
				[err, res] = await flatry(read(filepathconfig));

				// Log file contents.
				console.log(
					`[${chalk.bold(`.${commandname}.config${ext}`)}]\n`
				);
				console.log(res);
			}
		} else {
			// If acdef file does not exist log a message and exit script.
			exit([
				`acdef file for command ${chalk.bold(
					commandname
				)} does not exist.`
			]);
		}
	}
};
