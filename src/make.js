"use strict";

// Needed modules.
const fs = require("fs");
const path = require("path");
const chalk = require("chalk");
const slash = require("slash");
const log = require("fancy-log");
const mkdirp = require("mkdirp");
const fe = require("file-exists");
const pe = require("path-exists");
const { fileinfo, exit, paths } = require("./utils.js");

module.exports = args => {
	// Get needed paths.
	let { homedir, cdirname, acmapspath } = paths;

	// Get CLI args.
	let { source, print, add } = args;
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
	if (!/^[a-z][a-z0-9-_]{2,}\.acmapfile$/i.test(fi.name)) {
		exit([
			`File name must follow format: ${chalk.bold.blue(
				"<cli-command-name>.acmapfile"
			)}.`,
			`Examples: ${chalk.bold("prettier.acmapfile")}, ${chalk.bold(
				"prettier-cli-watcher.acmapfile"
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

		// Save ac definitions file to source location.
		fs.writeFileSync(
			path.join(fi.dirname, `${commandname}.acdeffile`),
			acmap
		);

		// Add to maps location if add flag provided.
		if (add) {
			let commandpath = path.join(acmapspath, commandname);
			if (!fe.sync(commandpath) || args.force) {
				// Save file to map location.
				fs.writeFileSync(commandpath, acmap);
				log(`${chalk.bold(commandname)} acmapfile added.`);
			} else {
				log(
					`acmapfile ${chalk.bold(
						commandname
					)} exists (use ${chalk.bold(
						"--force"
					)} to overwrite current acmapfile).`
				);
			}
		}

		// Log acmap file contents if print flag provided.
		if (print) {
			console.log(acmap);
		}
	});
};
