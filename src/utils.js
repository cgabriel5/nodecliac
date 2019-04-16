"use strict";

// Needed modules.
var fs = require("fs");
const os = require("os");
const path = require("path");
var crypto = require("crypto");
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
let exit = (messages, stop, normal_log) => {
	// Log all provided messages.
	for (let i = 0, l = messages.length; i < l; i++) {
		// Cache current loop item.
		let message = messages[i];

		if (normal_log) {
			console.log(message);
		} else {
			log(message);
		}
	}

	if (stop === undefined) {
		process.exit();
	}
};
// Use console.log over fancy-log.
exit.normal = (messages, stop) => {
	exit(messages, stop, true);
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
	let cdirssrc = `${cdirname}/src`; // Source scripts.
	let customdir = path.join(homedir, `.${cdirname}`);
	let bashrcpath = path.join(homedir, ".bashrc");
	let mainscriptname = "main.sh";
	let mscriptpath = path.join(homedir, `.${cdirssrc}/${mainscriptname}`);
	let acscriptname = "ac.sh";
	let acscriptpath = path.join(homedir, `.${cdirssrc}/${acscriptname}`);
	let acplscriptname = "ac.pl";
	let acplscriptpath = path.join(homedir, `.${cdirssrc}/${acplscriptname}`);
	let acplscriptconfigname = "config.pl";
	let acplscriptconfigpath = path.join(
		homedir,
		`.${cdirssrc}/${acplscriptconfigname}`
	);
	let acmapspath = path.join(homedir, `.${cdirname}/defs`);
	let acmapssource = path.join(homedir, `.${cdirssrc}`);

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
		acmapspath,
		acmapssource
	};
})(os, path);

/**
 * Concat values from N sets into a main set.
 *
 * @param  {set} set - The main set iterable.
 * @param  {...set} iterables - N amount of sets.
 * @return {set} - The main set with other merged set values.
 *
 * @resource [https://stackoverflow.com/a/41328397]
 */
let concat_sets = function(set, ...iterables) {
	for (let iterable of iterables) {
		for (let item of iterable) {
			set.add(item);
		}
	}
};

/**
 * Generate checksum from provided string.
 *
 * @return {string} - The generated checksum.
 *
 * @resource [https://gist.github.com/zfael/a1a6913944c55843ed3e999b16350b50]
 * @resource [https://blog.abelotech.com/posts/calculate-checksum-hash-nodejs-javascript/]
 */
let checksum = (str, algorithm, encoding) => {
	return crypto
		.createHash(algorithm || "md5")
		.update(str, "utf8")
		.digest(encoding || "hex");
};

module.exports = {
	concat_sets,
	checksum,
	fileinfo,
	paths,
	exit
};
