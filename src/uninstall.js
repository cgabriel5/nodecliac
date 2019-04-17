"use strict";

// Needed modules.
const fs = require("fs");
const chalk = require("chalk");
const log = require("fancy-log");
const rimraf = require("rimraf");
const fe = require("file-exists");
const de = require("directory-exists");
const { exit, paths } = require("./utils.js");

module.exports = args => {
	// Get CLI args.
	let { rcfilepath } = args;

	// Get needed paths.
	let { customdir, bashrcpath, setupfilepath } = paths;

	// Custom dir needs to exist to completely remove.
	de(customdir, (err, exists) => {
		if (err) {
			console.error(err);
			process.exit();
		}

		// Exit if root directory does not exist.
		if (!exists) {
			log("Already removed or is not installed.");
			process.exit();
		}

		// Setup file needs to exist to remove .rcfile modifications.
		fe(setupfilepath, (err, exists) => {
			if (err) {
				console.error(err);
				process.exit();
			}

			// If a custom .rcfile path was provided use that instead.
			if (rcfilepath) {
				bashrcpath = rcfilepath;
			} else {
				// Get rcfile path from setup file.
				bashrcpath = exists
					? JSON.parse(fs.readFileSync(setupfilepath).toString())
							.rcfilepath
					: null;
			}

			rimraf(customdir, err => {
				if (err) {
					console.error(err);
					process.exit();
				}

				// If setup file exists we try to remove .rcfile modifications.
				if (bashrcpath) {
					// .rcfile file needs to exist to remove nodecliac marker.
					fe(bashrcpath, (err, exists) => {
						if (err) {
							console.error(err);
							process.exit();
						}

						// If .rcfile exists, remove marker if present.
						if (exists) {
							// Get .rcfile script contents.
							let contents = fs
								.readFileSync(bashrcpath)
								.toString();

							// Check for nodecliac marker.
							if (/^ncliac=~/m.test(contents)) {
								// Remove marker.
								fs.writeFileSync(
									bashrcpath,
									contents.replace(
										/ncliac=~[\s\S]*?"\$ncliac";\s*fi;/g,
										""
									)
								);
							}

							// Reverted .rcfile changes.
							log(
								`${chalk.green(
									"Successfully"
								)} reverted ${chalk.bold(bashrcpath)} changes.`
							);
						} else {
							log(
								`Could not revert ${chalk.bold(
									bashrcpath
								)} changes.`
							);
						}
					});
				} else {
					log("Could not revert rcfile changes.");
				}

				// Removed nodecliac root directory.
				log(
					`${chalk.green(
						"Successfully"
					)} removed nodecliac ${chalk.bold(customdir)}.`
				);
			});
		});
	});
};
