"use strict";

const path = require("path");
const chalk = require("chalk");
const log = require("fancy-log");
const {
	exit,
	paths,
	read,
	write,
	fexists,
	fmt
} = require("../utils/toolbox.js");

module.exports = async (args) => {
	let { enable, disable, script } = args;
	let dotfile = path.join(paths.ncliacdir, ".debugmode");
	let tstring = "";

	if (enable && disable) {
		let varg1 = chalk.bold("--enable");
		let varg2 = chalk.bold("--disable");
		tstring = "? and ? given when only one can be provided.";
		exit([fmt(tstring, varg1, varg2)]);
	}

	// 0=off , 1=debug , 2=debug + ac.pl , 3=debug + ac.nim
	if (enable) {
		await write(dotfile, script === "nim" ? 3 : script === "pl" ? 2 : 1);
		log(chalk.green("Enabled."));
	} else if (disable) {
		await write(dotfile, 0);
		log(chalk.red("Disabled."));
	} else {
		if (!(await fexists(dotfile))) await write(dotfile, 0);
		process.stdout.write(await read(dotfile));
	}
};
