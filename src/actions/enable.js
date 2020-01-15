"use strict";

const flatry = require("flatry");
const fe = require("file-exists");
const {
	paths,
	read,
	write,
	realpath,
	readdir
} = require("../utils/toolbox.js");

module.exports = async args => {
	let { registrypath } = paths; // Get needed paths.
	// eslint-disable-next-line no-unused-vars
	let err, res; // Declare empty variables to reuse for all await operations.

	let { all } = args; // CLI args.
	let packages = args._; // Get provided packages.
	let action = packages[0]; // Get main action.
	packages.shift(); // Remove action from list.
	let state = action === "enable" ? "false" : "true";

	// Get all packages when '--all' is provided.
	if (all) {
		[err, res] = await flatry(readdir(registrypath));
		packages = res;
	}

	// Loop over packages and remove each if its exists.
	for (let i = 0, l = packages.length; i < l; i++) {
		let pkg = packages[i]; // Cache current loop item.

		// Needed paths.
		let filepath = `${registrypath}/${pkg}/.${pkg}.config.acdef`;
		[err, res] = await flatry(realpath(filepath));
		let resolved_path = res;

		// Ensure file exists before anything.
		[err, res] = await flatry(fe(resolved_path));
		if (err || !res) continue;

		[err, res] = await flatry(read(resolved_path)); // Get config file contents.
		if (err) continue;

		// Remove current value from config.
		let contents = res.trim(); // Trim config before using.
		contents = contents.replace(/^@disable[^\n]*/gm, "").trim();
		contents += `\n@disable = ${state}\n`; // Add new value to config.

		// Cleanup contents.
		contents = contents.replace(/^\n/gm, ""); // Remove newlines.
		contents = contents.replace(/\n/, "\n\n"); // Add newline after header.

		[err, res] = await flatry(write(filepath, contents)); // Save changes.
		if (err) continue;
	}
};
