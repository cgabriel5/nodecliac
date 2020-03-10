"use strict";

const chalk = require("chalk");
const flatry = require("flatry");
const mkdirp = require("make-dir");
const de = require("directory-exists");
const { paths, rmrf, read, write, hasProp } = require("../utils/toolbox.js");

module.exports = async args => {
	let { cachepath, cachelevel } = paths;
	// eslint-disable-next-line no-unused-vars
	let err, res;

	let { clear, level } = args;

	if (clear) {
		[err, res] = await flatry(de(cachepath));
		if (!err) {
			await flatry(rmrf(cachepath));
			await flatry(mkdirp(cachepath));
			console.log(chalk.green("Successfully"), "cleared cache.");
		}
	}

	if (hasProp(args, "level")) {
		if (Number.isInteger(level)) {
			const levels = [0, 1, 2]; // Cache levels.
			await flatry(
				write(cachelevel, -~levels.indexOf(level) ? level : 1)
			);
		} else {
			[err, res] = await flatry(read(cachelevel));
			if (!err) console.log(res);
		}
	}
};
