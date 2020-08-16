"use strict";

const chalk = require("chalk");
const { exit, fmt } = require("../utils/toolbox.js");
const { initconfig, getsetting, setsetting } = require("../utils/config.js");

module.exports = async (args) => {
	let { enable, disable, script } = args;

	await initconfig();

	if (enable && disable) {
		let varg1 = chalk.bold("--enable");
		let varg2 = chalk.bold("--disable");
		let tstring = "? and ? given when only one can be provided.";
		exit([fmt(tstring, varg1, varg2)]);
	}

	// 0=off , 1=debug , 2=debug + ac.pl , 3=debug + ac.nim
	if (enable) {
		let dl = script === "nim" ? 3 : script === "pl" ? 2 : 1;
		await setsetting("debug", dl);
		console.log(chalk.green("on"));
	} else if (disable) {
		await setsetting("debug", 0);
		console.log(chalk.red("off"));
	} else {
		process.stdout.write(await getsetting("debug"));
	}
};
