"use strict";

// Needed modules.
var fs = require("fs");
const path = require("path");

/**
 * Wrapper for readFile method. Returns a Promise.
 *
 * @param  {string} filepath - The path of file to read.
 * @return {promise} - Promise is returned.
 */
let readdir = filepath => {
	return new Promise((resolve, reject) => {
		fs.readdir(filepath, (err, list) => {
			// Reject on error.
			if (err) reject(err);

			// Return directory contents list (array).
			resolve(list);
		});
	});
};

// // Cannot be a directory.
// fs.lstatSync(path.join(commandspaths, p)).isDirectory()

module.exports = {
	// strip_comments,
	readdir
	// write
};
