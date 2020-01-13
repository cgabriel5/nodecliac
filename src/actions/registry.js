"use strict";

const path = require("path");
const chalk = require("chalk");
const flatry = require("flatry");
const log = require("fancy-log");
const de = require("directory-exists");
const fe = require("file-exists");
const {
	exit,
	paths,
	readdir,
	lstats,
	realpath
} = require("../utils/toolbox.js");

module.exports = async () => {
	let { registrypaths } = paths; // Get needed paths.
	let files = [];
	// eslint-disable-next-line no-unused-vars
	let err, res; // Declare empty variables to reuse for all await operations.

	// Maps path needs to exist to list acdef files.
	[err, res] = await flatry(de(registrypaths));
	if (!res) exit([]); // Exit without message.

	// Get list of directory command folders.
	[err, res] = await flatry(readdir(registrypaths));
	let commands = res;

	// Loop over found command folders to get their respective
	// .acdef/config files.
	for (let i = 0, l = commands.length; i < l; i++) {
		let command = commands[i]; // Cache current loop item.

		// Build .acdef file paths.
		let acdefpath = path.join(registrypaths, command, `${command}.acdef`);
		let configfilename = `.${command}.config.acdef`;
		let configpath = path.join(registrypaths, command, configfilename);

		// Store information in a tuple.
		let tuple = [command, false];

		// If acdef file exists add information to tuple.
		[err, res] = await flatry(fe(acdefpath));
		if (res) {
			// Check for config file.
			[err, res] = await flatry(fe(configpath));
			if (res) tuple[1] = true; // Store config file path for later use.
		}

		// Add tuple to files array.
		files.push(tuple);
	}

	// List commands if any exist.
	if (files.length) {
		files
			.sort(function(a, b) {
				return a[0].localeCompare(b[0]);
			})
			.forEach(async function(tuple) {
				// Get file tuple information.
				let [command, hasconfig] = tuple;

				let pkgpath = `${registrypaths}/${command}`;
				[err, res] = await flatry(lstats(pkgpath));
				if (res.symlink) {
					// Get the real package path.
					[err, res] = await flatry(realpath(pkgpath));
					let resolved_path = chalk.bold.blue(res);
					let color = hasconfig ? "cyan" : "red";
					log(`${chalk.bold[color](command)} -> ${resolved_path}/`);
				} else {
					let color = hasconfig ? "blue" : "red";
					log(`${chalk.bold[color](command)}/`);
				}
			});
	}
};
