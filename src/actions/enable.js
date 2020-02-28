"use strict";

const flatry = require("flatry");
const fe = require("file-exists");
const toolbox = require("../utils/toolbox.js");
const { paths, read, write, realpath, readdir } = toolbox;

module.exports = async args => {
	let { registrypath } = paths;
	// eslint-disable-next-line no-unused-vars
	let err, res, resolved_path;

	let { all } = args;
	let packages = args._;
	let action = packages[0];
	packages.shift();
	let state = action === "enable" ? "false" : "true";

	// Get all packages when '--all' is provided.
	if (all) [err, packages] = await flatry(readdir(registrypath));

	// Loop over packages and remove each if its exists.
	for (let i = 0, l = packages.length; i < l; i++) {
		let pkg = packages[i];

		let filepath = `${registrypath}/${pkg}/.${pkg}.config.acdef`;
		[err, resolved_path] = await flatry(realpath(filepath));

		[err, res] = await flatry(fe(resolved_path));
		if (err || !res) continue;
		[err, res] = await flatry(read(resolved_path));
		if (err) continue;

		let contents = res.trim();
		contents = contents.replace(/^@disable[^\n]*/gm, "").trim();
		contents += `\n@disable = ${state}\n`;
		contents = contents.replace(/^\n/gm, ""); // Remove newlines.
		contents = contents.replace(/\n/, "\n\n"); // Add newline after header.

		[err, res] = await flatry(write(filepath, contents));
		if (err) continue;
	}
};
