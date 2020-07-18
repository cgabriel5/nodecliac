"use strict";

const chalk = require("chalk");
const flatry = require("flatry");
const mkdirp = require("make-dir");
const de = require("directory-exists");
const { paths, rmrf, read, write, hasProp } = require("../utils/toolbox.js");

module.exports = async (args) => {
	let { cachepath, cachelevel } = paths;
	let { clear, level } = args;

	if (clear) {
		let [err] = await flatry(de(cachepath));
		if (!err) {
			await rmrf(cachepath);
			await mkdirp(cachepath);
			console.log(chalk.green("Successfully"), "cleared cache.");
		}
	}

	if (hasProp(args, "level")) {
		if (Number.isInteger(level)) {
			const levels = [0, 1, 2]; // Cache levels.
			await write(cachelevel, -~levels.indexOf(level) ? level : 1);
		} else {
			let [err, res] = await flatry(read(cachelevel));
			if (!err) console.log(res.trim());
		}
	}
};
