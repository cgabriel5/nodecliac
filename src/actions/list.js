"use strict";

// Needed modules.
const path = require("path");
const chalk = require("chalk");
const flatry = require("flatry");
const log = require("fancy-log");
const de = require("directory-exists");
const fe = require("file-exists");
const { exit, paths, readdir } = require("../utils/toolbox.js");

module.exports = async () => {
	// Get needed paths.
	let { commandspaths } = paths;
	let files = [];

	// Declare empty variables to reuse for all await operations.
	let err, res;

	// Maps path needs to exist to list acdef files.
	[err, res] = await flatry(de(commandspaths));
	if (!res) {
		exit([]); // Just exit without message.
	}

	// Get list of directory command folders.
	[err, res] = await flatry(readdir(commandspaths));
	let commands = res;

	// Loop over found command folders to get their respective
	// .acdef/config files.
	for (let i = 0, l = commands.length; i < l; i++) {
		// Cache current loop item.
		let command = commands[i];

		// Build .acdef file paths.
		let acdefpath = path.join(commandspaths, command, `${command}.acdef`);
		let configpath = path.join(
			commandspaths,
			command,
			`.${command}.config.acdef`
		);

		// Store information in a tuple.
		let tuple = [];

		// If acdef file exists add information to tuple.
		[err, res] = await flatry(fe(acdefpath));
		if (res) {
			tuple.push(command);

			// Check for config file.
			[err, res] = await flatry(fe(configpath));
			if (res) {
				// Store config file path for later use.
				tuple.push(true);
			}

			// Add tuple to files array.
			files.push(tuple);
		}
	}

	// List commands if any exist.
	if (files.length) {
		log(chalk.bold(`.acdef files: (${files.length})`));

		files
			.sort(function(a, b) {
				return a[0].localeCompare(b[0]);
			})
			.forEach(function(tuple) {
				// Get file tuple information.
				let [command, hasconfig] = tuple;

				// Check if config file exists.
				let config_marker = hasconfig ? "*" : "";
				log(
					` ─ ${chalk[config_marker ? "bold" : "black"](
						chalk[config_marker ? "blue" : "black"](command)
					)}${config_marker}`
				);
			});
	}
};
