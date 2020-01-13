"use strict";

const flatry = require("flatry");
const mkdirp = require("make-dir");
const de = require("directory-exists");
const rimraf = require("rimraf");
const { paths } = require("../utils/toolbox.js");

module.exports = async args => {
	let { registrypaths } = paths; // Get needed paths.
	// eslint-disable-next-line no-unused-vars
	let err, res; // Declare empty variables to reuse for all await operations.

	let { all } = args; // CLI args.
	let packages = args._; // Get provided packages.
	packages.shift(); // Remove action from list.

	// Empty registry when `--all` flag is provided.
	if (all) {
		// Delete registry.
		// Wrap rimraf in a promise.
		let primraf = new Promise((resolve, reject) => {
			rimraf(registrypaths, err => {
				if (err) reject(err); // Return err if rimraf failed.
				resolve(true);
			});
		});

		[err, res] = await flatry(primraf); // Delete directory.
		[err, res] = await flatry(mkdirp(registrypaths)); // Create registry.
		packages.length = 0; // Empty packages array to skip loop.
	}

	// Loop over packages and remove each if its exists.
	for (let i = 0, l = packages.length; i < l; i++) {
		let pkg = packages[i]; // Cache current loop item.

		// Needed paths.
		let destination = `${registrypaths}/${pkg}`;

		// If folder does not exist don't ao anything.
		[err, res] = await flatry(de(destination));
		if (err || !res) continue;

		// Wrap rimraf in a promise.
		let primraf = new Promise((resolve, reject) => {
			rimraf(destination, err => {
				if (err) reject(err); // Return err if rimraf failed.
				resolve(true);
			});
		});

		[err, res] = await flatry(primraf); // Delete directory.
	}
};
