"use strict";

// Needed modules.
const fs = require("fs");
const chalk = require("chalk");
const log = require("fancy-log");
const rimraf = require("rimraf");
const flatry = require("flatry");
const fe = require("file-exists");
const de = require("directory-exists");
const { exit, paths } = require("../utils/main.js");
const { read, write } = require("../utils/file.js");

module.exports = async args => {
	// Get CLI args.
	let { rcfilepath } = args;
	// Get needed paths.
	let { customdir, bashrcpath, setupfilepath } = paths;
	// Declare empty variables to reuse for all await operations.
	let err, res;

	// Custom dir needs to exist to completely remove.
	[err, res] = await flatry(de(customdir));

	// Exit if root directory does not exist.
	if (!res) {
		exit(["Already removed or is not installed."]);
	}

	// Setup file needs to exist to remove .rcfile modifications.
	[err, res] = await flatry(fe(setupfilepath));

	// If a custom .rcfile path was provided use that instead.
	if (rcfilepath) {
		bashrcpath = rcfilepath;
	} else {
		// Get rcfile contents.
		[err, res] = await flatry(read(setupfilepath));

		// Get rcfile path from setup file.
		bashrcpath = res ? JSON.parse(res).rcfilepath : null;
	}

	// Wrap rimraf in a promise.
	let primraf = new Promise((resolve, reject) => {
		// Run rimraf.
		rimraf(customdir, err => {
			// Return err if rimraf failed.
			if (err) {
				reject(err);
			}

			resolve(true);
		});
	});

	// Delete nodecliac directory.
	[err, res] = await flatry(primraf);

	// If setup file exists we try to remove .rcfile modifications.
	if (bashrcpath) {
		// .rcfile file needs to exist to remove nodecliac marker.
		[err, res] = await flatry(fe(bashrcpath));

		// If .rcfile exists, remove marker if present.
		if (res) {
			// Get .rcfile script contents.
			[err, res] = await flatry(read(bashrcpath));

			// Check for nodecliac marker.
			if (/^ncliac=~/m.test(res)) {
				// Remove marker.
				[err, res] = await flatry(
					write(
						bashrcpath,
						res.replace(/ncliac=~[\s\S]*?"\$ncliac";\s*fi;/g, "")
					)
				);
			}

			// Reverted .rcfile changes.
			log(
				`${chalk.green("Successfully")} reverted ${chalk.bold(
					bashrcpath
				)} changes.`
			);
		} else {
			log(`Could not revert ${chalk.bold(bashrcpath)} changes.`);
		}
	} else {
		log("Could not revert rcfile changes.");
	}

	// Removed nodecliac root directory.
	log(
		`${chalk.green("Successfully")} removed nodecliac ${chalk.bold(
			customdir
		)}.`
	);
};
