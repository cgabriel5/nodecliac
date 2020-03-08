"use strict";

const chalk = require("chalk");
const flatry = require("flatry");
const mkdirp = require("make-dir");
const de = require("directory-exists");
const { paths, rmrf } = require("../utils/toolbox.js");

module.exports = async args => {
	let { cachepath } = paths;
	// eslint-disable-next-line no-unused-vars
	let err, res;

	let { clear } = args;

	if (clear) {
		[err, res] = await flatry(de(cachepath));
		if (!err) {
			await flatry(rmrf(cachepath));
			await flatry(mkdirp(cachepath));
			console.log(chalk.green("Successfully"), "cleared cache.");
		}
	}
};
