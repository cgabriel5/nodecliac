"use strict";

const chalk = require("chalk");
const fe = require("file-exists");
const { exit, paths, read, fmt } = require("../utils/toolbox.js");

module.exports = async (args) => {
	let { registrypath } = paths;
	let { command } = args;
	// eslint-disable-next-line no-unused-vars
	let err, res;
	let tstring = "";

	// Source must be provided.
	if (!command) {
		tstring = "Please provide a command name using the ? flag.";
		exit([fmt(tstring, chalk.bold("--command"))]);
	}

	// If command is supplied then print its acdef/config file contents.
	if (command) {
		// Break apart command.
		let [, cmdname = ""] = command.match(/^(.*?)(\.(acdef))?$/);
		let ext = ".acdef";

		// Exit and give error if a command name not provided.
		if (!cmdname) {
			tstring = "Please provide a command name (i.e. --command=?).";
			exit([fmt(tstring, chalk.bold("nodecliac.acdef"))]);
		}

		// Check if command chain contains invalid characters.
		let r = /[^-._:a-zA-Z0-9\\/]/;
		if (r.test(cmdname)) {
			// Loop over command chain to highlight invalid character.
			let chars = [];
			let invalid_char_count = 0;
			for (let i = 0, l = cmdname.length; i < l; i++) {
				let char = cmdname[i];

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
		let pathstart = `${registrypath}/${cmdname}`;
		let filepath = `${pathstart}/${cmdname}${ext}`;
		let filepathconfig = `${pathstart}/.${cmdname}.config${ext}`;

		// Check if acdef file exists. Print file contents.
		if (await fe(filepath)) {
			// Log file contents.
			console.log(`\n[${chalk.bold(`${cmdname}${ext}`)}]\n`);
			console.log(await read(filepath));

			// Check if config file exists. Print file contents.
			if (await fe(filepathconfig)) {
				// Log file contents.
				let header = chalk.bold(`.${cmdname}.config${ext}`);
				console.log(`[${header}]\n`);
				console.log(await read(filepathconfig));
			}
		} else {
			// If acdef file does not exist log a message and exit script.
			let bcmdname = chalk.bold(cmdname);
			exit([`acdef file for command ${bcmdname} does not exist.`]);
		}
	}
};
