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
		// File paths.
		let filepath = `${customdir}/defs/${command}.acdef`;
		let filepathconfig = `${customdir}/defs/.${command}.config.acdef`;

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
					console.log(`[${chalk.bold(`${command}.acdef`)}]\n`);
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
								`[${chalk.bold(`.${command}.config.acdef`)}]\n`
							);
							console.log(data.toString());
						});
					}
				});
			} else {
				// If acdef file does not exist log a message and exit script.
				exit([
					`acdef file for command ${chalk.bold(
						command
					)} does not exist.`
				]);
			}
		});
	}
};
