"use strict";

const chalk = require("chalk");
const shell = require("shelljs");
const fe = require("file-exists");
const de = require("directory-exists");
const { paths, read, write, rmrf } = require("../utils/toolbox.js");

module.exports = async (args) => {
	let { rcfile } = args;
	let { ncliacdir, bashrcpath, setupfilepath } = paths;

	shell.exec("sudo echo > /dev/null 2>&1"); // Prompt password.

	// Delete nodecliac dir.
	if (await de(ncliacdir)) await rmrf(ncliacdir);

	// Get bashrc file contents.
	if (rcfile) bashrcpath = rcfile;
	else {
		let res = await fe(setupfilepath);
		if (res) {
			if (await read(setupfilepath)) {
				bashrcpath = JSON.parse(res).rcfile || bashrcpath;
			}
		}
	}

	// Remove .rcfile modifications.
	if (bashrcpath) {
		if (await fe(bashrcpath)) {
			let res = await read(bashrcpath);
			if (/^ncliac=~/m.test(res)) {
				res = res.replace(/([# \t]*)\bncliac.*"\$ncliac";?\n?/g, "");
				await write(bashrcpath, res);

				let varg1 = chalk.green("success");
				let varg2 = chalk.bold(bashrcpath);
				console.log(`${varg1} reverted ${varg2} changes.`);
			}
		}
	}

	// Remove nodecliac global module from npm/yarn.
	// $ yarn global bin/ $ yarn global list / $ npm list --silent -q -g --depth=0
	shell.exec(
		'[ -n "$(command -v yarn)" ] && "$(command -v npm)" global remove nodecliac > /dev/null 2>&1; ' +
			'[ -n "$(command -v npm)" ] && sudo "$(command -v npm)" uninstall -g nodecliac > /dev/null 2>&1',
		{ silent: true },
		(/*code, stdout, stderr*/) => {
			let varg1 = chalk.green("success");
			console.log(`${varg1} removed nodecliac global module.`);
		}
	);
};
