"use strict";

// Needed modules.
const fs = require("fs");
const chalk = require("chalk");
const fe = require("file-exists");
const { exit, paths } = require("./utils.js");

module.exports = args => {
	// Get needed paths.
	let { customdir } = paths;

	// Get CLI args.
	let { command } = args;

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
		let filepath = `${customdir}/defs/${commandname}${ext}`;
		let filepathconfig = `${customdir}/defs/.${commandname}.config${ext}`;

		// Check if acdef file exists.
		fe(filepath, (err, exists) => {
			if (err) {
				console.error(err);
				process.exit();
			}

			// Print file contents.
			if (exists) {
				fs.readFile(filepath, function(err, data) {
					if (err) {
						console.error(err);
						process.exit();
					}

					// Log file contents.
					console.log(`[${chalk.bold(`${commandname}${ext}`)}]\n`);
					console.log(data.toString());
				});

				// Check if config file exists.
				fe(filepathconfig, (err, exists) => {
					if (err) {
						console.error(err);
						process.exit();
					}

					// Print file contents.
					if (exists) {
						fs.readFile(filepathconfig, function(err, data) {
							if (err) {
								console.error(err);
								process.exit();
							}

							// Log file contents.
							console.log(
								`[${chalk.bold(
									`.${commandname}.config${ext}`
								)}]\n`
							);
							console.log(data.toString());
						});
					}
				});
			} else {
				// If acdef file does not exist log a message and exit script.
				exit([
					`acdef file for command ${chalk.bold(
						commandname
					)} does not exist.`
				]);
			}
		});
	}
};
