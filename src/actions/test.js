"use strict";

const os = require("os");
const chalk = require("chalk");
const shell = require("shelljs");
const flatry = require("flatry");
const fe = require("file-exists");
const de = require("directory-exists");
const { paths, exit } = require("../utils/toolbox.js");

module.exports = async (args) => {
	let { registrypath } = paths;
	let packages = args._;
	packages.shift();

	/**
	 * Wrapper function which promisifies the shell.exec function.
	 *
	 * @param  {string} cmd - The command to execute.
	 * @param  {object} opts - The options object.
	 * @param  {function} callback - The callback function.
	 * @return {promise} - The wrapped promise.
	 *
	 * @resource [https://gist.github.com/davidrleonard/2962a3c40497d93c422d1269bcd38c8f]
	 */
	function aexec(cmd, opts = {} /*, callback*/) {
		return new Promise((resolve, reject) => {
			shell.exec(cmd, opts, (code, stdout, stderr) => {
				if (/*code !== 0* || */ stderr) return reject(stderr);
				return resolve(stdout);
			});
		});
	}

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
		let callback = (/*code, stdout, stderr*/) => {};
		await aexec(cmd, opts, callback);
	}
};
