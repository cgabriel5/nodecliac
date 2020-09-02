"use strict";

const chalk = require("chalk");
const { exit, fmt } = require("../utils/toolbox.js");
const { initconfig, getsetting, setsetting } = require("../utils/config.js");

module.exports = async (args) => {
	let { enable, disable } = args;

	await initconfig();

	// If no flag is supplied only print the status.
	if (!enable && !disable) {
		let status = await getsetting("status");
		let message = status === "1" ? chalk.green("on") : chalk.red("off");
		console.log(message);
	} else {
		if (enable && disable) {
			let varg1 = chalk.bold("--enable");
			let varg2 = chalk.bold("--disable");
			let tstring = "? and ? given when only one can be provided.";
			exit([fmt(tstring, varg1, varg2)]);
		}

		if (enable) {
			await setsetting("status", 1);
			console.log(chalk.green("on"));
		} else if (disable) {
			// let contents = `Disabled: ${new Date()};${Date.now()}`;
			await setsetting("status", 0);
			console.log(chalk.red("off"));
		}
	}
};
