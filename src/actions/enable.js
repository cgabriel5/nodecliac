"use strict";

const path = require("path");
const chalk = require("chalk");
const flatry = require("flatry");
// const de = require("directory-exists");
const fe = require("file-exists");
// const symlink = require("symlink-dir");
const {
	// fmt,
	// exit,
	paths,
	read,
	write,
	realpath
} = require("../utils/toolbox.js");

module.exports = async args => {
	let { registrypaths } = paths; // Get needed paths.
	// eslint-disable-next-line no-unused-vars
	let err, res; // Declare empty variables to reuse for all await operations.

	let packages = args._; // Get provided packages.
	packages.shift(); // Remove action from list.

	// Loop over packages and remove each if its exists.
	for (let i = 0, l = packages.length; i < l; i++) {
		let pkg = packages[i]; // Cache current loop item.

		// Needed paths.
		let filepath = `${registrypaths}/${pkg}/.${pkg}.config.acdef`;
		[err, res] = await flatry(realpath(filepath));
		let resolved_path = res;

		// Ensure file exists before anything.
		[err, res] = await flatry(fe(resolved_path));
		if (err || !res) continue;

		[err, res] = await flatry(read(resolved_path)); // Get config file contents.
		if (err) continue;

		// Remove current value from config.
		let contents = res.trim(); // Trim config before using.
		contents = contents.replace(/^\@disable[^\n]*/gm, "").trim();
		contents += "\n@disable = false\n"; // Add new value to config.

		// Cleanup contents.
		contents = contents.replace(/^\n/gm, ""); // Remove newlines.
		contents = contents.replace(/\n/, "\n\n"); // Add newline after header.

		[err, res] = await flatry(write(filepath, contents)); // Save changes.
		if (err) continue;
	}
};
