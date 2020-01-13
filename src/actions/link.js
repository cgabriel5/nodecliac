"use strict";

const path = require("path");
const chalk = require("chalk");
const flatry = require("flatry");
const de = require("directory-exists");
const symlink = require("symlink-dir");
const { fmt, exit, paths, lstats } = require("../utils/toolbox.js");

module.exports = async args => {
	let { registrypaths } = paths; // Get needed paths.
	// eslint-disable-next-line no-unused-vars
	let err, res; // Declare empty variables to reuse for all await operations.
	let msg = "";
	let varg1 = "";
	let varg2 = "";

	let { force } = args; // CLI args.

	// Needed paths.
	let cwd = process.cwd();
	let dirname = path.basename(cwd); // Get package name.
	let destination = `${registrypaths}/${dirname}`;

	[err, res] = await flatry(de(cwd)); // Confirm cwd exists.
	if (err || !res) process.exit();

	// Now, to create a symlink one of two things: either there is no package
	// currently in the registry with the same name or if there is the package
	// is already a symlink in which case we just overwrite it.
	[err, res] = await flatry(de(destination));
	if (err) process.exit();
	if (res) {
		// If folder is not a symlink don't symlink.
		[err, res] = await flatry(lstats(destination));
		if (!res.symlink) {
			msg = "Real package ? exists. Cannot link.";
			if (err || res) {
				exit([fmt(msg, chalk.bold(dirname))], true);
				msg = `Run '?' and try again.`;
				varg1 = chalk.bold(`$ nodecliac remove ${dirname}`);
				exit([fmt(msg, varg1)]);
			}
		}
	}

	[err, res] = await flatry(symlink(cwd, destination)); // Create symlink.
};
