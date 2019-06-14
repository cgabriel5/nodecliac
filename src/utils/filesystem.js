"use strict";

// Needed modules.
const fs = require("fs");
const path = require("path");
const ext = require("file-extension");

/**
 * Wrapper for readFile method. Returns a Promise.
 *
 * @param  {string} filepath - The path of file to read.
 * @return {promise} - Promise is returned.
 */
let read = filepath => {
	return new Promise((resolve, reject) => {
		fs.readFile(filepath, (err, data) => {
			// Reject on error.
			if (err) reject(err);

			// Return file contents on success.
			resolve(data.toString());
		});
	});
};
/**
 * Wrapper for writeFile method. Returns a Promise.
 *
 * @param  {string} filepath - The path of file to read.
 * @param  {string} data - The file's contents.
 * @param  {string} mode - The script's mode (chmod) value.
 * @return {promise} - Promise is returned.
 */
let write = (filepath, data, mode) => {
	return new Promise((resolve, reject) => {
		fs.writeFile(filepath, data, err => {
			// Apply file mode if supplied.
			if (mode) {
				// Using options.mode does not work as expected:
				// [https://github.com/nodejs/node/issues/1104]
				// [https://github.com/nodejs/node/issues/2249]
				// [https://github.com/nodejs/node-v0.x-archive/issues/25756]
				// [https://x-team.com/blog/file-system-permissions-umask-node-js/]

				// Apply file mode (chmod) explicitly.
				fs.chmod(filepath, mode, err => {
					// Reject on error.
					if (err) reject(err);

					// Return true boolean on success.
					resolve(true);
				});
			} else {
				// Reject on error.
				if (err) reject(err);

				// Return true boolean on success.
				resolve(true);
			}
		});
	});
};

/**
 * Wrapper for unlink method. Returns a Promise.
 *
 * @param  {string} filepath - The path of file to remove.
 * @return {promise} - Promise is returned.
 */
let remove = filepath => {
	return new Promise((resolve, reject) => {
		fs.unlink(filepath, err => {
			// Reject on error.
			if (err) reject(err);

			// Return file contents on success.
			resolve(true);
		});
	});
};

/**
 * Get file path information (i.e. file name and directory path).
 *
 * @param  {string} filepath - The complete file path.
 * @return {object} - Object containing file path components.
 */
let info = filepath => {
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

module.exports = {
	readdir,
	remove,
	write,
	info,
	read
};
