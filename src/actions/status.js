"use strict";

const path = require("path");
const chalk = require("chalk");
const flatry = require("flatry");
const log = require("fancy-log");
const fe = require("file-exists");
const { exit, paths, remove, write, fmt } = require("../utils/toolbox.js");

module.exports = async args => {
	let { customdir } = paths; // Get needed paths.
	let { enable, disable } = args; // Get CLI args.
	let dotfile = path.join(customdir, ".disable"); // Dot file path.
	// eslint-disable-next-line no-unused-vars
	let err, res; // Declare empty variables to reuse for all await operations.
	let tstring = "";

	// If no flag is supplied then only print the status.
	if (!enable && !disable) {
		[err, res] = await flatry(fe(dotfile));

		let message = res ? chalk.red("disabled") : chalk.green("enabled");
		log(`nodecliac: ${message}`); // Print status.
	} else {
		// If both flags are provided give message and exit.
		if (enable && disable) {
			let varg1 = chalk.bold("--enable");
			let varg2 = chalk.bold("--disable");
			tstring = // Template string.
				"Both ? and ? flags supplied but only one can be provided.";
			exit([fmt(tstring, varg1, varg2)]);
		}

		// If enable flag provided..
		if (enable) {
			[err, res] = await flatry(fe(dotfile)); // Remove dot file.
			if (res) {
				[err, res] = await flatry(remove(dotfile)); // Remove script.
				log(chalk.green("Enabled.")); // Log success message.
			} else log(chalk.green("Enabled.")); // Log success message.
		}
		// If disable flag provided...
		else if (disable) {
			// Create blocking dot file.
			let contents = `Disabled: ${new Date()};${Date.now()}`;
			[err, res] = await flatry(write(dotfile, contents));

			log(chalk.red("Disabled.")); // Log success message.
		}
	}
};
