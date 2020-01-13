"use strict";

const os = require("os");
const path = require("path");

/**
 * Generate needed project paths.
 *
 * @return {object} - Object containing needed paths.
 */
let paths = (function(os, path) {
	// Get/create needed paths.
	// let pwd = process.env.PWD; // [https://stackoverflow.com/a/39740187]
	let cwd = path.dirname(path.dirname(__dirname)); // [https://stackoverflow.com/a/29496638]
	let homedir = os.homedir(); // [https://stackoverflow.com/a/9081436]
	let cdirname = "nodecliac"; // Custom directory name.
	let customdir = path.join(homedir, `.${cdirname}`);
	let bashrcpath = path.join(homedir, ".bashrc");
	let mainscriptname = "init.sh";
	let registrypaths = path.join(homedir, `.${cdirname}`, "registry");
	let acmapssource = path.join(homedir, `.${cdirname}`, "src");
	let setupfilepath = path.join(customdir, `.setup.db.json`);
	// Path to nodecliac resources.
	let resourcespath = path.join(cwd, "resources/packages/");
	let resourcessrcs = path.join(cwd, "src/scripts/");

	return {
		cwd,
		homedir,
		cdirname,
		customdir,
		bashrcpath,
		mainscriptname,
		registrypaths,
		acmapssource,
		setupfilepath,
		resourcespath,
		resourcessrcs
	};
})(os, path);

module.exports = {
	paths
};
