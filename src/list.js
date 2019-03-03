"use strict";

// Needed modules.
const fs = require("fs");
const path = require("path");
const chalk = require("chalk");
const log = require("fancy-log");
const de = require("directory-exists");
const { paths } = require("./utils.js");

module.exports = () => {
	// Get needed paths.
	let { acmapspath } = paths;

	// Maps path needs to exist to list acdef files.
	de(acmapspath, (err, exists) => {
		if (err) {
			console.error(err);
			process.exit();
		}

		// Exit if path does not exist.
		if (!exists) {
			log(`Path: ${chalk.bold(acmapspath)} does not exist.`);
			process.exit();
		}

		// Store config files.
		let configs = [];

		// Get acdef files list.
		fs.readdir(acmapspath, function(err, files) {
			if (err) {
				console.error(err);
				process.exit();
			}

			// Only get files.
			files = files.filter(function(p) {
				let is_configfile = p.includes(".config.acdef");
				// Store config files.
				if (is_configfile) {
					configs.push(p);
				}

				return !(
					is_configfile || // No .config.acdef files.
					// Cannot be a directory.
					fs.lstatSync(path.join(acmapspath, p)).isDirectory()
				);
			});

			// List commands if any exist.
			if (files.length) {
				log(chalk.bold(`.acdef files: (${files.length})`));

				files
					.sort(function(a, b) {
						return a.localeCompare(b);
					})
					.forEach(function(command) {
						// Check if config file exists.
						let config_marker = configs.includes(
							`.${command.replace(".acdef", ".config.acdef")}`
						)
							? "*"
							: "";
						log(
							` ─ ${chalk[config_marker ? "bold" : "black"](
								chalk[config_marker ? "blue" : "black"](command)
							)}${config_marker}`
						);
					});
			} else {
				log(chalk.bold("No .acdef files found."));
			}
		});
	});
};
