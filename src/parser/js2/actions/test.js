"use strict";

const os = require("os");
const chalk = require("chalk");
const shell = require("shelljs");
const flatry = require("flatry");
const fe = require("file-exists");
const de = require("directory-exists");
const { paths, exit, aexec } = require("../utils/toolbox.js");

module.exports = async (args) => {
	let { registrypath } = paths;
	let packages = args._;
	packages.shift();

	let errscript = os.homedir() + "/.nodecliac/src/main/test.sh";
	let [err, res] = await flatry(fe(errscript));
	if (err || !res) exit([`File ${chalk.bold(errscript)} doesn't exit.`]);

	// Remove provided packages.
	for (let i = 0, l = packages.length; i < l; i++) {
		let pkg = packages[i];
		let pkgpath = `${registrypath}/${pkg}`;

		let [err, res] = await flatry(de(pkgpath));
		if (err || !res) continue;
		let test = `${pkgpath}/${pkg}.tests.sh`;
		[err, res] = await flatry(fe(test));
		if (err || !res) continue;

		let cmd = `${errscript} -p true -f true -t ${test}`;
		let opts = { silent: false, async: true };
		await aexec(cmd, opts, callback);
	}
};
