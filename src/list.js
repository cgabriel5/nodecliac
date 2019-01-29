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

		// Get acdef files list.
		fs.readdir(acmapspath, function(err, files) {
			if (err) {
				console.error(err);
				process.exit();
			}

			// Only get files.
			files = files.filter(function(p) {
				return !fs.lstatSync(path.join(acmapspath, p)).isDirectory();
			});

			// List commands if any exist.
			if (files.length) {
				log(chalk.bold(`.acdef files: (${files.length})`));

				files
					.sort(function(a, b) {
						return a.localeCompare(b);
					})
					.forEach(function(command) {
						log(` ─ ${chalk.bold.blue(command)}`);
					});
			} else {
				log(chalk.bold("No .acdef files found."));
			}
		});
	});
};
