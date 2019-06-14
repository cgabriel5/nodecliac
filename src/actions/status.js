"use strict";

// Needed modules.
const fs = require("fs");
const path = require("path");
const chalk = require("chalk");
const flatry = require("flatry");
const log = require("fancy-log");
const fe = require("file-exists");
const { exit, paths } = require("../utils/main.js");
const { remove, write } = require("../utils/file.js");

module.exports = async args => {
	// Get needed paths.
	let { customdir } = paths;
	// Get CLI args.
	let { enable, disable } = args;
	// Dot file path.
	let dotfile = path.join(customdir, ".disable");
	// Declare empty variables to reuse for all await operations.
	let err, res;

	// If no flag is supplied then only print the status.
	if (!enable && !disable) {
		[err, res] = await flatry(fe(dotfile));

		// Print status.
		let message = res ? chalk.red("disabled") : chalk.green("enabled");
		log(`nodecliac: ${message}`);
	} else {
		// Enable/disable nodecliac.
		// If both flags are provided give message and exit.
		if (enable && disable) {
			exit([
				`Both ${chalk.bold("--enable")} and ${chalk.bold(
					"--disable"
				)} flags were supplied but only one can be provided.`
			]);
		}

		// If enable flag provided..
		if (enable) {
			// Remove dot file.
			[err, res] = await flatry(fe(dotfile));
			if (res) {
				// Remove script.
				[err, res] = await flatry(remove(dotfile));
				// Log success message.
				log(chalk.green("Enabled."));
			} else {
				// Log success message.
				log(chalk.green("Enabled."));
			}
		} else if (disable) {
			// If disable flag provided...

			// Create blocking dot file.
			[err, res] = await flatry(
				write(dotfile, `Disabled: ${new Date()};${Date.now()}`)
			);

			// Log success message.
			log(chalk.red("Disabled."));
		}
	}
};
