"use strict";

const path = require("path");
const chalk = require("chalk");
const flatry = require("flatry");
const mkdirp = require("make-dir");
const de = require("directory-exists");
const copydir = require("recursive-copy");
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

	// If folder exists give error.
	[err, res] = await flatry(de(destination));
	if (err || res) {
		[err, res] = await flatry(lstats(destination));
		// If folder is not a symlink don't symlink.
		if (res.symlink) {
			msg = "Symlink package ? exists. Cannot add.";
			varg1 = chalk.bold(dirname);
			if (err || res) {
				exit([fmt(msg, chalk.bold(dirname))], true);
				msg = `Run '?' and try again.`;
				varg1 = chalk.bold(`$ nodecliac remove ${dirname}`);
				exit([fmt(msg, varg1)]);
			}
		} else {
			msg = "Package ? already exists. Use ? to overwrite.";
			varg1 = chalk.bold(dirname);
			varg2 = chalk.bold("--force");
			exit([fmt(msg, varg1, varg2)]);
		}
	}

	// Create needed parent directories.
	[err, res] = await flatry(mkdirp(destination));

	// Copy folder to nodecliac registry.
	let options = { overwrite: true, dot: true, debug: false };
	[err, res] = await flatry(copydir(cwd, destination, options));
};
