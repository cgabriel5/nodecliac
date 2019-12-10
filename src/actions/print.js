"use strict";

const chalk = require("chalk");
const flatry = require("flatry");
const fe = require("file-exists");
const { exit, paths, read, fmt } = require("../utils/toolbox.js");

module.exports = async args => {
	let { registrypaths } = paths; // Get needed paths.
	let { command } = args; // Get CLI args.
	// eslint-disable-next-line no-unused-vars
	let err, res; // Declare empty variables to reuse for all await operations.
	let tstring = "";

	// Source must be provided.
	if (!command) {
		tstring = "Please provide a command name using the ? flag.";
		exit([fmt(tstring, chalk.bold("--command"))]);
	}

	// If command is supplied then print its acdef/config file contents.
	if (command) {
		// Break apart command.
		let [, commandname = ""] = command.match(/^(.*?)(\.(acdef))?$/);
		let ext = ".acdef";

		// Exit and give error if a command name not provided.
		if (!commandname) {
			tstring = "Please provide a command name (i.e. --command=?).";
			exit([fmt(tstring, chalk.bold("nodecliac.acdef"))]);
		}

		// Check if command chain contains invalid characters.
		let r = /[^-._:a-zA-Z0-9\\/]/;
		if (r.test(commandname)) {
			// Loop over command chain to highlight invalid character.
			let chars = [];
			let invalid_char_count = 0;
			for (let i = 0, l = commandname.length; i < l; i++) {
				let char = commandname[i]; // Cache current loop item.

				// If an invalid character highlight.
				if (r.test(char)) {
					chars.push(chalk.bold.red(char));
					invalid_char_count++;
				} else chars.push(char);
			}

			// Plural output character string.
			let char_string = `character${invalid_char_count > 1 ? "s" : ""}`;

			// Invalid escaped command-flag found.
			let varg1 = chalk.bold("Invalid:");
			let varg3 = chars.join("");
			exit([fmt("? ? in command: ?", varg1, char_string, varg3)]);
		}

		// File paths.
		let pathstart = `${registrypaths}/${commandname}`;
		let filepath = `${pathstart}/${commandname}${ext}`;
		let filepathconfig = `${pathstart}/.${commandname}.config${ext}`;

		// Check if acdef file exists.
		[err, res] = await flatry(fe(filepath));

		// Print file contents.
		if (res) {
			[err, res] = await flatry(read(filepath));

			// Log file contents.
			console.log(`\n[${chalk.bold(`${commandname}${ext}`)}]\n`);
			console.log(res);

			// Check if config file exists.
			[err, res] = await flatry(fe(filepathconfig));
			// Print file contents.
			if (res) {
				[err, res] = await flatry(read(filepathconfig));

				// Log file contents.
				let header = chalk.bold(`.${commandname}.config${ext}`);
				console.log(`[${header}]\n`);
				console.log(res);
			}
		} else {
			// If acdef file does not exist log a message and exit script.
			let bcommandname = chalk.bold(commandname);
			exit([`acdef file for command ${bcommandname} does not exist.`]);
		}
	}
};
