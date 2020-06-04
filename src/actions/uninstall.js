"use strict";

const chalk = require("chalk");
const log = require("fancy-log");
const flatry = require("flatry");
const shell = require("shelljs");
const fe = require("file-exists");
const de = require("directory-exists");
const { paths, read, write, rmrf } = require("../utils/toolbox.js");

module.exports = async (args) => {
	let { rcfile } = args;
	let { ncliacdir, bashrcpath, setupfilepath } = paths;
	// eslint-disable-next-line no-unused-vars
	let err, res;

	shell.exec("sudo echo > /dev/null 2>&1"); // Prompt password.

	// Delete nodecliac dir.
	[err, res] = await flatry(de(ncliacdir));
	if (res) await flatry(rmrf(ncliacdir));

	// Get bashrc file contents.
	if (rcfile) bashrcpath = rcfile;
	else {
		[err, res] = await flatry(fe(setupfilepath));
		if (res) {
			[err, res] = await flatry(read(setupfilepath));
			if (res) bashrcpath = JSON.parse(res).rcfile || bashrcpath;
		}
	}

	// Remove .rcfile modifications.
	if (bashrcpath) {
		[err, res] = await flatry(fe(bashrcpath));
		if (res) {
			[err, res] = await flatry(read(bashrcpath));
			if (/^ncliac=~/m.test(res)) {
				res = res.replace(/([# \t]*)\bncliac.*"\$ncliac";?\n?/g, "");
				await flatry(write(bashrcpath, res));

				let varg1 = chalk.green("Successfully");
				let varg2 = chalk.bold(bashrcpath);
				log(`${varg1} reverted ${varg2} changes.`);
			}
		}
	}

	// Remove nodecliac global module from npm/yarn.
	// $ yarn global bin/ $ yarn global list / $ npm list --silent -q -g --depth=0
	shell.exec(
		"[ -n $(command -v yarn) ] && yarn global remove nodecliac > /dev/null 2>&1; " +
			"[ -n $(command -v npm) ] && sudo npm uninstall -g nodecliac > /dev/null 2>&1",
		{ silent: true },
		(/*code, stdout, stderr*/) => {
			let varg1 = chalk.green("Successfully");
			log(`${varg1} removed nodecliac global module.`);
		}
	);
};
