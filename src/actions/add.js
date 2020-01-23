"use strict";

const path = require("path");
const chalk = require("chalk");
const flatry = require("flatry");
const mkdirp = require("make-dir");
const de = require("directory-exists");
const copydir = require("recursive-copy");
const { fmt, exit, paths, lstats } = require("../utils/toolbox.js");

module.exports = async (/*args*/) => {
	let { registrypath } = paths; // Get needed paths.
	// eslint-disable-next-line no-unused-vars
	let err, res; // Declare empty variables to reuse for all await operations.

	// TODO: Add logic to validate folder being added?

	// Needed paths.
	let cwd = process.cwd();
	let dirname = path.basename(cwd); // Get package name.
	let destination = `${registrypath}/${dirname}`;

	// If folder exists give error.
	[err, res] = await flatry(de(destination));
	if (err) process.exit();
	if (res) {
		// Check if folder is a symlink.
		[err, res] = await flatry(lstats(destination));
		let type = res.is.symlink ? "Symlink " : "";
		let msg = `${type}?/ exists. First remove and try again.`;
		exit([fmt(msg, chalk.bold(dirname))]);
	}

	// Create needed parent directories.
	[err, res] = await flatry(mkdirp(destination));

	// Copy folder to nodecliac registry.
	let options = { overwrite: true, dot: true, debug: false };
	[err, res] = await flatry(copydir(cwd, destination, options));
};