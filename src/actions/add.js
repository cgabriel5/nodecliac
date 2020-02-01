"use strict";

const path = require("path");
const chalk = require("chalk");
const flatry = require("flatry");
const mkdirp = require("make-dir");
const de = require("directory-exists");
const copydir = require("recursive-copy");
const { fmt, exit, paths, lstats } = require("../utils/toolbox.js");

module.exports = async () => {
	let { registrypath } = paths;
	// eslint-disable-next-line no-unused-vars
	let err, res;

	// TODO: Add logic to validate folder being added?

	let cwd = process.cwd();
	let dirname = path.basename(cwd);
	let pkgpath = `${registrypath}/${dirname}`;

	// If package exists error.
	[err, res] = await flatry(de(pkgpath));
	if (err) process.exit();
	if (res) {
		[err, res] = await flatry(lstats(pkgpath));
		let type = res.is.symlink ? "Symlink " : "";
		let msg = `${type}?/ exists. Remove it and try again.`;
		exit([fmt(msg, chalk.bold(dirname))]);
	}

	// Copy folder to nodecliac registry.
	await flatry(mkdirp(pkgpath));
	let options = { overwrite: true, dot: true, debug: false };
	await flatry(copydir(cwd, pkgpath, options));
};
