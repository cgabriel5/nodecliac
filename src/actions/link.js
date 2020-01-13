"use strict";

const path = require("path");
const chalk = require("chalk");
const flatry = require("flatry");
const de = require("directory-exists");
const symlink = require("symlink-dir");
const { fmt, exit, paths, lstats } = require("../utils/toolbox.js");

module.exports = async (/*args*/) => {
	let { registrypaths } = paths; // Get needed paths.
	// eslint-disable-next-line no-unused-vars
	let err, res; // Declare empty variables to reuse for all await operations.

	// Needed paths.
	let cwd = process.cwd();
	let dirname = path.basename(cwd); // Get package name.
	let destination = `${registrypaths}/${dirname}`;

	[err, res] = await flatry(de(cwd)); // Confirm cwd exists.
	if (err || !res) process.exit();

	// If folder exists give error.
	[err, res] = await flatry(de(destination));
	if (err) process.exit();
	if (res) {
		// Check if folder is a symlink.
		[err, res] = await flatry(lstats(destination));
		let type = res.symlink ? "Symlink" : "";
		let msg = `${type} ?/ exists. First remove and try again.`;
		exit([fmt(msg, chalk.bold(dirname))]);
	}

	[err, res] = await flatry(symlink(cwd, destination)); // Create symlink.
};
