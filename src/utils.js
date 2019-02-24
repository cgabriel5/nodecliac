"use strict";

// Needed modules.
const os = require("os");
const path = require("path");
const log = require("fancy-log");
const ext = require("file-extension");

/**
 * Get file path information (i.e. file name and directory path).
 *
 * @param  {string} filepath - The complete file path.
 * @return {object} - Object containing file path components.
 */
let fileinfo = filepath => {
	// Get file extension.
	let extension = ext(filepath);
	// Get file name and directory path.
	let name = path.basename(filepath);
	let dirname = path.dirname(filepath);

	return {
		name,
		dirname,
		ext: extension,
		path: filepath
	};
};

/**
 * Logs messages then exits script.
 *
 * @param  {array} message - List of messages to log.
 * @return {undefined} - Nothing.
 */
let exit = messages => {
	// Log all provided messages.
	for (let i = 0, l = messages.length; i < l; i++) {
		// Cache current loop item.
		let message = messages[i];

		log(message);
	}
	process.exit();
};

/**
 * Generate needed project paths.
 *
 * @return {object} - Object containing needed paths.
 */
let paths = (function(os, path) {
	// Get/create needed paths.
	// [https://stackoverflow.com/a/9081436]
	let homedir = os.homedir();
	let cdirname = "nodecliac"; // Custom directory name.
	let customdir = path.join(homedir, `.${cdirname}`);
	let bashrcpath = path.join(homedir, ".bashrc");
	let mainscriptname = "main.sh";
	let mscriptpath = path.join(homedir, `.${cdirname}/${mainscriptname}`);
	let acscriptname = "ac.sh";
	let acscriptpath = path.join(homedir, `.${cdirname}/${acscriptname}`);
	let acplscriptname = "ac.pl";
	let acplscriptpath = path.join(homedir, `.${cdirname}/${acplscriptname}`);
	let acplscriptconfigname = "config.pl";
	let acplscriptconfigpath = path.join(
		homedir,
		`.${cdirname}/${acplscriptconfigname}`
	);
	let acmapspath = path.join(homedir, `.${cdirname}/defs`);

	return {
		homedir,
		cdirname,
		customdir,
		bashrcpath,
		mainscriptname,
		mscriptpath,
		acscriptname,
		acscriptpath,
		acplscriptname,
		acplscriptpath,
		acplscriptconfigpath,
		acmapspath
	};
})(os, path);

module.exports = {
	fileinfo,
	paths,
	exit
};
