"use strict";

const path = require("path");
const chalk = require("chalk");
const flatry = require("flatry");
const de = require("directory-exists");
const symlink = require("symlink-dir");
const { fmt, exit, paths, lstats } = require("../utils/toolbox.js");

module.exports = async () => {
	let { registrypath } = paths;
	// eslint-disable-next-line no-unused-vars
	let err, res;

	let cwd = process.cwd();
	let dirname = path.basename(cwd);
	let pkgpath = `${registrypath}/${dirname}`;

	[err, res] = await flatry(de(cwd));
	if (err || !res) process.exit();

	// If package exists error.
	[err, res] = await flatry(de(pkgpath));
	if (err) process.exit();
	if (res) {
		[err, res] = await flatry(lstats(pkgpath));
		let type = res.is.symlink ? "Symlink " : "";
		let msg = `${type}?/ exists. Remove it and try again.`;
		exit([fmt(msg, chalk.bold(dirname))]);
	}

	await flatry(symlink(cwd, pkgpath));
};
