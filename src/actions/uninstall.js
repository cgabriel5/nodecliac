"use strict";

// Needed modules.
const chalk = require("chalk");
const log = require("fancy-log");
const rimraf = require("rimraf");
const flatry = require("flatry");
const shell = require("shelljs");
const fe = require("file-exists");
const de = require("directory-exists");
const { paths, read, write } = require("../utils/toolbox.js");

module.exports = async args => {
	// Get CLI args.
	let { rcfilepath } = args;
	// Get needed paths.
	let { customdir, bashrcpath, setupfilepath } = paths;
	// Declare empty variables to reuse for all await operations.
	// eslint-disable-next-line no-unused-vars
	let err, res;

	// Prompt password early on. Also ensures user really wants to uninstall.
	shell.exec("sudo echo > /dev/null 2>&1");

	// Custom dir needs to exist to completely remove.
	[err, res] = await flatry(de(customdir));

	// If a custom .rcfile path was provided use that instead.
	if (rcfilepath) {
		bashrcpath = rcfilepath;

		// Else looup up setup file for rcfilepath.
	} else {
		// If setup file exists look for .rcfile path.
		[err, res] = await flatry(fe(setupfilepath));
		if (res) {
			// Get rcfile contents.
			[err, res] = await flatry(read(setupfilepath));
			if (res) {
				// Get rcfile path from setup file if available.
				bashrcpath = JSON.parse(res).rcfilepath || bashrcpath;
			}
		}
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

				// Reverted .rcfile changes.
				log(
					`${chalk.green("Successfully")} reverted ${chalk.bold(
						bashrcpath
					)} changes.`
				);
			}
		}
	}

	// Remove nodecliac global module from npm and yarn.
	// yarn global bin
	// yarn global list
	// npm list --silent -q -g --depth=0
	shell.exec(
		"[ -n $(command -v yarn) ] && yarn global remove nodecliac > /dev/null 2>&1; [ -n $(command -v npm) ] && sudo npm uninstall -g nodecliac > /dev/null 2>&1",
		{ silent: true },
		(/*code, stdout, stderr*/) => {
			log(
				`${chalk.green(
					"Successfully"
				)} removed nodecliac global module.`
			);
		}
	);
};
