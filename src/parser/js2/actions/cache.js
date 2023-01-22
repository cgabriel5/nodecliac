"use strict";

const path = require("path");
const chalk = require("chalk");
const flatry = require("flatry");
const de = require("directory-exists");
const { paths, readdir, remove, hasProp } = require("../utils/toolbox.js");
const { initconfig, getsetting, setsetting } = require("../utils/config.js");

module.exports = async (args) => {
	let { cachepath } = paths;
	let { clear, level } = args;

	await initconfig();

	if (clear) {
		let [err, res] = await flatry(de(cachepath));
		if (!err) {
			let [err, files] = await flatry(readdir(cachepath));
			if (!files) files = [];
			for (let i = 0, l = files.length; i < l; i++) {
				await remove(path.join(cachepath, files[i]));
			}
			console.log(chalk.green("success"), "Cleared cache");
		}
	}

	if (hasProp(args, "level")) {
		if (Number.isInteger(level)) {
			const levels = [0, 1, 2]; // Cache levels.
			await setsetting("cache", -~levels.indexOf(level) ? level : 1);
		} else {
			process.stdout.write(await getsetting("cache"));
		}
	}
};
