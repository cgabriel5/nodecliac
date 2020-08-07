"use strict";

const path = require("path");
const chalk = require("chalk");
const flatry = require("flatry");
const de = require("directory-exists");
const { paths, read, write } = require("../utils/toolbox.js");
const { readdir, remove, hasProp } = require("../utils/toolbox.js");

module.exports = async (args) => {
	let { cachepath, cachelevel } = paths;
	let { clear, level } = args;

	if (clear) {
		let [err] = await flatry(de(cachepath));
		if (!err) {
			let files = await readdir(cachepath);
			for (let i = 0, l = files.length; i < l; i++) {
				await remove(path.join(cachepath, files[i]));
			}
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
