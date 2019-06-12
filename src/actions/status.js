"use strict";

// Needed modules.
const fs = require("fs");
const path = require("path");
const chalk = require("chalk");
const log = require("fancy-log");
const fe = require("file-exists");
const { exit, paths } = require("../utils/main.js");

module.exports = args => {
	// Get needed paths.
	let { customdir } = paths;

	// Get CLI args.
	let { enable, disable } = args;

	// Dot file path.
	let dotfile = path.join(customdir, ".disable");

	// If no flag is supplied then only print the status.
	if (!enable && !disable) {
		fe(dotfile, (err, exists) => {
			if (err) {
				console.error(err);
				process.exit();
			}

			// Print status.
			if (exists) {
				log("nodecliac:", chalk.red("disabled"));
			} else {
				log("nodecliac:", chalk.green("enabled"));
			}
		});
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
			if (fe.sync(dotfile)) {
				// Remove script.
				fs.unlink(dotfile, function(err) {
					if (err) {
						console.error(err);
						process.exit();
					}

					// Log success message.
					log(chalk.green("Enabled."));
				});
			} else {
				// Log success message.
				log(chalk.green("Enabled."));
			}
		} else if (disable) {
			// If disable flag provided...

			// Create blocking dot file.
			fs.writeFileSync(dotfile, `Disabled: ${new Date()};${Date.now()}`);

			// Log success message.
			log(chalk.red("Disabled."));
		}
	}
};
