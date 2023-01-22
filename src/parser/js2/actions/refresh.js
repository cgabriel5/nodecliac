"use strict";

const path = require("path");
const de = require("directory-exists");
const chalk = require("chalk");
const flatry = require("flatry");
const toolbox = require("../utils/toolbox.js");
const { download, paths } = toolbox;

module.exports = async (args) => {
	let { ncliacdir } = paths;

	// Check that project directory exists.
	let err, res;
	[err, res] = await flatry(de(ncliacdir));
	if (res) {
		console.log(chalk.bold.cyan("Downloading"), "Official package list");
		let url = "https://raw.githubusercontent.com/cgabriel5/nodecliac/master/resources/packages/packages.json";
		[err, res] = await flatry(download.file(url, ncliacdir, "packages.json"));
		console.log("    " + chalk.bold.green("Success"), "Package list updated");
	}
};
