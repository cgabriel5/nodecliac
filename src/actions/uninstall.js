"use strict";

const chalk = require("chalk");
const log = require("fancy-log");
const rimraf = require("rimraf");
const flatry = require("flatry");
const shell = require("shelljs");
const fe = require("file-exists");
const de = require("directory-exists");
const { paths, read, write } = require("../utils/toolbox.js");

module.exports = async args => {
	let { rcfilepath } = args; // Get CLI args.
	let { customdir, bashrcpath, setupfilepath } = paths; // Get needed paths.
	// eslint-disable-next-line no-unused-vars
	let err, res; // Declare empty vars to reuse for all await operations.

	// Prompt password early on. Also ensures user really wants to uninstall.
	shell.exec("sudo echo > /dev/null 2>&1");

	// Custom dir needs to exist to completely remove.
	[err, res] = await flatry(de(customdir));

	// If a custom .rcfile path was provided use that instead.
	if (rcfilepath) bashrcpath = rcfilepath;
	// Else looup up setup file for rcfilepath.
	else {
		// If setup file exists look for .rcfile path.
		[err, res] = await flatry(fe(setupfilepath));
		if (res) {
			[err, res] = await flatry(read(setupfilepath)); // Get rcfile contents.
			// Get rcfile path from setup file if available.
			if (res) bashrcpath = JSON.parse(res).rcfilepath || bashrcpath;
		}
	}

	// Wrap rimraf in a promise.
	let primraf = new Promise((resolve, reject) => {
		rimraf(customdir, err => {
			if (err) reject(err); // Return err if rimraf failed.
			resolve(true);
		});
	});

	[err, res] = await flatry(primraf); // Delete nodecliac directory.

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
				res = res.replace(/ncliac=~[\s\S]*?"\$ncliac";\s*fi;/g, "");
				// Remove marker.
				[err, res] = await flatry(write(bashrcpath, res));

				// Reverted .rcfile changes.
				let varg1 = chalk.green("Successfully");
				let varg2 = chalk.bold(bashrcpath);
				log(`${varg1} reverted ${varg2} changes.`);
			}
		}
	}

	// Remove nodecliac global module from npm/yarn.
	// $ yarn global bin/ $ yarn global list / $ npm list --silent -q -g --depth=0
	shell.exec(
		"[ -n $(command -v yarn) ] && yarn global remove nodecliac > /dev/null 2>&1; [ -n $(command -v npm) ] && sudo npm uninstall -g nodecliac > /dev/null 2>&1",
		{ silent: true },
		(/*code, stdout, stderr*/) => {
			let varg1 = chalk.green("Successfully");
			log(`${varg1} removed nodecliac global module.`);
		}
	);
};
