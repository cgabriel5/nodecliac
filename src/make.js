"use strict";

// Needed modules.
const fs = require("fs");
const path = require("path");
const chalk = require("chalk");
const log = require("fancy-log");
const fe = require("file-exists");
const { fileinfo, exit, paths } = require("./utils.js");

module.exports = args => {
	// Get needed paths.
	let { acmapspath } = paths;

	// Get CLI args.
	let { source, print, add, save } = args;
	let parser = require("./parser.js");

	// Source must be provided.
	if (!source) {
		exit([`Please provide a ${chalk.bold("--source")} path.`]);
	}
	if (typeof source !== "string") {
		exit([`${chalk.bold("--source")} needs to be a string.`]);
	}
	// Check path for file name and extension.
	let fi = fileinfo(source);
	if (!/^[a-z][a-z0-9-_]{2,}\.acmap$/i.test(fi.name)) {
		exit([
			`File name must follow format: ${chalk.bold.blue(
				"<cli-command-name>.acmap"
			)}.`,
			`Examples: ${chalk.bold("prettier.acmap")}, ${chalk.bold(
				"prettier-cli-watcher.acmap"
			)}.`
		]);
	}
	// Extract the command name.
	let commandname = fi.name.match(/^[a-z0-9-_]+/g)[0].replace(/_/g, "-");

	// Turn source path to absolute path.
	source = path.join(process.cwd(), source);

	// Check that the source path exists.
	fe(source, (err, exists) => {
		if (err) {
			console.error(err);
			process.exit();
		}

		// If path does not exist, give message and end process.
		if (!exists) {
			exit([`${chalk.bold(source)} does not exist.`]);
		}

		// Generate acmap.
		let acmap = parser(fs.readFileSync(source).toString());
		let savename = `${commandname}.acdef`;

		// Save definitions file to source location when flag is provided.
		if (save) {
			fs.writeFileSync(path.join(fi.dirname, savename), acmap);
		}

		// Add to maps location if add flag provided.
		if (add) {
			let commandpath = path.join(acmapspath, savename);
			if (!fe.sync(commandpath) || args.force) {
				// Save file to map location.
				fs.writeFileSync(commandpath, acmap);
				log(`${chalk.bold(commandname)} acmap added.`);
			} else {
				log(
					`acmap ${chalk.bold(commandname)} exists (use ${chalk.bold(
						"--force"
					)} to overwrite current acmap).`
				);
			}
		}

		// Log acmap file contents if print flag provided.
		if (print) {
			console.log(acmap);
		}
	});
};
