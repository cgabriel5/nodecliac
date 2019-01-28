"use strict";

// Needed modules.
const fs = require("fs");
const chalk = require("chalk");
const log = require("fancy-log");
const rimraf = require("rimraf");
const fe = require("file-exists");
const de = require("directory-exists");
const { paths } = require("./utils.js");

module.exports = () => {
	// Get needed paths.
	let { customdir, bashrcpath } = paths;

	// Custom dir needs to exist to completely remove.
	de(customdir, (err, exists) => {
		if (err) {
			console.error(err);
			process.exit();
		}

		// Exit if already removed.
		if (!exists) {
			log(chalk.blue("Already removed."));
			process.exit();
		}

		rimraf(customdir, err => {
			if (err) {
				console.error(err);
				process.exit();
			}

			// .bashrc file needs to exist to remove nodecliac marker.
			fe(bashrcpath, (err, exists) => {
				if (err) {
					console.error(err);
					process.exit();
				}

				// If .bashrc exists, remove marker if present.
				if (exists) {
					// Get .bashrc script contents.
					let contents = fs.readFileSync(bashrcpath).toString();

					// Check for nodecliac marker.
					if (contents.includes("[nodecliac]")) {
						// Remove marker.
						fs.writeFileSync(
							bashrcpath,
							contents.replace(
								/\n?#\s*\[nodecliac\][\s\S]*\[\/nodecliac\]\s*#\n?$/m,
								""
							)
						);
					}
				}

				log(chalk.green("Successfully removed."));
			});
		});
	});
};
