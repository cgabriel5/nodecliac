"use strict";

const path = require("path");
const chalk = require("chalk");
const log = require("fancy-log");
const fe = require("file-exists");
const { exit, paths, remove, write, fmt } = require("../utils/toolbox.js");

module.exports = async (args) => {
	let { enable, disable } = args;
	let dotfile = path.join(paths.ncliacdir, ".disable");
	// eslint-disable-next-line no-unused-vars
	let tstring = "";

	// If no flag is supplied then only print the status.
	if (!enable && !disable) {
		let message = (await fe(dotfile))
			? chalk.red("disabled")
			: chalk.green("enabled");
		log(`nodecliac: ${message}`);
	} else {
		if (enable && disable) {
			let varg1 = chalk.bold("--enable");
			let varg2 = chalk.bold("--disable");
			tstring = "? and ? given when only one can be provided.";
			exit([fmt(tstring, varg1, varg2)]);
		}

		if (enable) {
			if (await fe(dotfile)) {
				await remove(dotfile);
				log(chalk.green("Enabled."));
			} else log(chalk.green("Enabled."));
		} else if (disable) {
			// Create blocking dot file.
			let contents = `Disabled: ${new Date()};${Date.now()}`;
			await write(dotfile, contents);
			log(chalk.red("Disabled."));
		}
	}
};
