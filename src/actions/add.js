"use strict";

const du = require("du");
const path = require("path");
const chalk = require("chalk");
const flatry = require("flatry");
const mkdirp = require("make-dir");
const de = require("directory-exists");
const copydir = require("recursive-copy");
const { fmt, exit, paths, lstats } = require("../utils/toolbox.js");

module.exports = async (args) => {
	let { registrypath } = paths;
	let { force } = args;

	let cwd = process.cwd();
	let dirname = path.basename(cwd);
	let pkgpath = `${registrypath}/${dirname}`;

	// If package exists error.
	let [err, res] = await flatry(de(pkgpath));
	if (err) process.exit();
	if (res) {
		let type = (await lstats(pkgpath)).is.symlink ? "Symlink " : "";
		let msg = `${type}?/ exists. Remove it and try again.`;
		exit([fmt(msg, chalk.bold(dirname))]);
	}

	// Skip size check when --force is provided.
	if (!force) {
		// Anything larger than 10MB must be force added.
		if ((await du(cwd)) / 1000 > 10000) {
			let msg = `?/ exceeds 10MB. Use --force to add package anyway.`;
			exit([fmt(msg, chalk.bold(dirname))]);
		}
	}

	// Copy folder to nodecliac registry.
	await mkdirp(pkgpath);
	let options = { overwrite: true, dot: true, debug: false };
	await copydir(cwd, pkgpath, options);
};
