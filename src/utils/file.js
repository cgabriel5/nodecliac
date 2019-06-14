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
 * Remove all comments from Bash/Perl files.
 *
 * @param  {string} contents - The file contents.
 * @return {string} - The file contents with comments removed.
 */
let strip_comments = contents => {
	return (
		contents
			// Inject acmap.
			// .replace(/# \[\[__acmap__\]\]/, acmap)
			// Remove comments/empty lines but leave sha-bang comment.
			.replace(/^\s*#(?!!).*?$/gm, "")
			.replace(/\s{1,}#\s{1,}.+$/gm, "")
			// .replace(/(^\s*#.*?$|\s{1,}#\s{1,}.*$)/gm, "")
			.replace(/(\r\n\t|\n|\r\t){1,}/gm, "\n")
			.trim()
	);
};

module.exports = {
	strip_comments,
	remove,
	write,
	read
};
