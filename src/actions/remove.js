"use strict";

const flatry = require("flatry");
const mkdirp = require("make-dir");
const de = require("directory-exists");
const { paths, rmrf } = require("../utils/toolbox.js");

module.exports = async (args) => {
	let { registrypath } = paths;
	let { all } = args;
	let packages = args._;
	packages.shift();

	// Empty registry when `--all` flag is provided.
	if (all) {
		await flatry(rmrf(registrypath));
		await flatry(mkdirp(registrypath));
		packages.length = 0; // Empty array to skip loop.
	}

	// Remove provided packages.
	for (let i = 0, l = packages.length; i < l; i++) {
		let pkg = packages[i];
		let pkgpath = `${registrypath}/${pkg}`;

		let [err, res] = await flatry(de(pkgpath));
		if (err || !res) continue;
		await flatry(rmrf(pkgpath));
	}
};
