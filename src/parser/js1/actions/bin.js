"use strict";

const shell = require("shelljs");

module.exports = async (args) => {
	process.stdout.write(
		shell.exec("command -v nodecliac", { silent: true }).stdout
	);
};
