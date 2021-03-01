"use strict";

const path = require("path");
const chalk = require("chalk");
const flatry = require("flatry");
const fe = require("file-exists");
const { exit, aexec, hasProp } = require("../utils/toolbox.js");

/**
 * Checks whether completion package has a valid base structure.
 *
 * @param  {string} command - The completion package command.
 * @param  {string} dir     - The directory path of package.
 * @return {boolean} - The validation check result.
 */
module.exports = async (...args) => {
	let result = true;

	let prefix = `${chalk.red("Error:")} Package missing ./`;
	let perror = function(file) {
		result = false;
		console.log(`${prefix}${chalk.bold(file)}`);
	};

	// If a single item is provided a folder contents
	// check is performed.
	if (args.length === 2) {
		let [command, dir] = args;
		// Validate repo's basic package structure: Must
		// contain: acmap, acdef, and config.acdef root files.
		let ini = "package.ini";
		let acmap = `${command}.acmap`;
		let acdef = `${command}.acdef`;
		let config = `.${command}.config.acdef`;
		let inipath = path.join(dir, ini);
		let acmappath = path.join(dir, acmap);
		let acdefpath = path.join(dir, acdef);
		let configpath = path.join(dir, config);
		if (!(await flatry(fe(acmappath)))[1]) perror(acmap);
		if (!(await flatry(fe(acdefpath)))[1]) perror(acdef);
		if (!(await flatry(fe(configpath)))[1]) perror(config);
		if (!(await flatry(fe(inipath)))[1]) perror(ini);
	} else {
		let [command, contents] = args;
		contents = contents.trim();
		let files = contents.split("\n");
		let bfiles = { // Base files.
			"package.ini": true,
			[`${command}.acmap`]: true,
			[`${command}.acdef`]: true,
			[`.${command}.config.acdef`]: true
		};
		let size = Object.keys(bfiles).length;
		for (let i = 0, l = files.length; i < l; i++) {
			let item = files[i];
			if (hasProp(bfiles, item)) {
				size--;
				delete bfiles[item];
				if (!size) break;
			}
		}
		if (size) for (const prop in bfiles) perror(prop);
	}

	return result;
};
