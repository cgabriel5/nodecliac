"use strict";

const path = require("path");
const chalk = require("chalk");
const flatry = require("flatry");
const log = require("fancy-log");
const de = require("directory-exists");
const fe = require("file-exists");
const { exit, paths, readdir } = require("../utils/toolbox.js");

module.exports = async () => {
	let { registrypaths } = paths; // Get needed paths.
	let files = [];
	// eslint-disable-next-line no-unused-vars
	let err, res; // Declare empty variables to reuse for all await operations.

	// Maps path needs to exist to list acdef files.
	[err, res] = await flatry(de(registrypaths));
	if (!res) exit([]); // Exit without message.

	// Get list of directory command folders.
	[err, res] = await flatry(readdir(registrypaths));
	let commands = res;

	// Loop over found command folders to get their respective
	// .acdef/config files.
	for (let i = 0, l = commands.length; i < l; i++) {
		let command = commands[i]; // Cache current loop item.

		// Build .acdef file paths.
		let acdefpath = path.join(registrypaths, command, `${command}.acdef`);
		let configfilename = `.${command}.config.acdef`;
		let configpath = path.join(registrypaths, command, configfilename);

		// Store information in a tuple.
		let tuple = [];

		// If acdef file exists add information to tuple.
		[err, res] = await flatry(fe(acdefpath));
		if (res) {
			tuple.push(command);

			// Check for config file.
			[err, res] = await flatry(fe(configpath));
			if (res) tuple.push(true); // Store config file path for later use.

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

				let varg1 = chalk[config_marker ? "bold" : "black"](
					chalk[config_marker ? "blue" : "black"](command)
				);
				log(` ─ ${varg1}${config_marker}`);
			});
	}
};
