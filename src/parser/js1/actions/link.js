"use strict";

const path = require("path");
const chalk = require("chalk");
const flatry = require("flatry");
const de = require("directory-exists");
const symlink = require("symlink-dir");
const { fmt, exit, paths, lstats, ispath_abs } = require("../utils/toolbox.js");

module.exports = async (args) => {
	let { registrypath } = paths;
	let { path: p } = args;

	if (p) if (!ispath_abs(p)) p = path.resolve(p);

	let cwd = p || process.cwd();
	let dirname = path.basename(cwd);
	let pkgpath = `${registrypath}/${dirname}`;

	let [err, res] = await flatry(de(cwd));
	if (err || !res) process.exit();

	// If package exists error.
	[err, res] = await flatry(de(pkgpath));
	if (err) process.exit();
	if (res) {
		[, res] = await flatry(lstats(pkgpath));
		let type = res.is.symlink ? "Symlink " : "";
		let msg = `${type}?/ exists. Remove it and try again.`;
		exit([fmt(msg, chalk.bold(dirname))]);
	}

	await symlink(cwd, pkgpath);
};
