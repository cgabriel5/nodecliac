"use strict";

// Needed modules.
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
	let mainscriptname = "main.sh";
	let commandspaths = path.join(homedir, `.${cdirname}`, "commands");
	let acmapssource = path.join(homedir, `.${cdirname}`, "src");
	let setupfilepath = path.join(customdir, `.setup.db.json`);
	// Path to nodecliac resources.
	let resourcespath = path.join(cwd, "resources/nodecliac/");

	return {
		cwd,
		homedir,
		cdirname,
		customdir,
		bashrcpath,
		mainscriptname,
		commandspaths,
		acmapssource,
		setupfilepath,
		resourcespath
	};
})(os, path);

module.exports = {
	paths
};
