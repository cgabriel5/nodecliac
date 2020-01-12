"use strict";

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
 * Wrapper for copyFile method. Returns a Promise.
 *
 * @param  {string} filepath - The path of file to copy.
 * @return {promise} - Promise is returned.
 *
 * @resource [https://stackoverflow.com/a/46253698]
 */
let copy = (filepath, destination) => {
	return new Promise((resolve, reject) => {
		fs.copyFile(filepath, destination, err => {
			// Reject on error.
			if (err) reject(err);

			// Return boolean on success.
			resolve(true);
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

/**
 * Check whether resource path is indeed absolute.
 *
 * @param  {string} p - The file path to check.
 * @return {boolean} - True if path is absolute, else false.
 *
 * @resource [https://stackoverflow.com/a/30450519]
 * @resource [https://stackoverflow.com/a/30714706]
 * @resource [http://www.linfo.org/path.html]
 * @resource [http://www.linfo.org/root_directory.html]
 * @resource [https://medium.com/@colinlmcdonald/absolute-vs-relative-paths-7ffd8e31d49c]
 */
let ispath_abs = p => {
	return (
		path.isAbsolute(p) &&
		path.normalize(p + "/") === path.normalize(path.resolve(p) + "/")
	);
};

/**
 * Get file paths stats.
 *
 * @param  {string} filepath - The file path to use.
 * @return {object} - The file path's stats object.
 *
 * @resource [https://stackoverflow.com/a/15630832]
 * @resource [https://pubs.opengroup.org/onlinepubs/7908799/xsh/lstat.html]
 * @resource [https://www.brainbell.com/javascript/fs-stats-structure.html]
 */
let lstats = filepath => {
	return new Promise((resolve, reject) => {
		fs.lstat(filepath, (err, stats) => {
			if (err) reject(err); // Reject on error.

			// Check if path is a symbolic link, add prop to object.
			// [https://stackoverflow.com/a/11287004]
			stats.symlink = stats.isSymbolicLink();

			// Return file contents on success.
			resolve(stats);
		});
	});
};

/**
 * Resolve paths `real` path. This means solving symlinks.
 *
 * @param  {string} filepath - The file path to use.
 * @return {string} - The resolved real path.
 *
 * @resource [https://nodejs.org/docs/latest/api/fs.html#fs_fs_realpath_path_options_callback]
 */
let realpath = filepath => {
	return new Promise((resolve, reject) => {
		fs.realpath(filepath, (err, resolved_path) => {
			if (err) reject(err); // Reject on error.

			resolve(resolved_path); // Return resolved true path.
		});
	});
};

/**
 * Use provided path to build the file's correct source path.
 *
 * @param  {string} filepath - The source's file path.
 * @return {string} - The corrected source's file path.
 */
// let fixpath = filepath => {
// 	return path.join(path.dirname(__dirname), filepath);
// };

module.exports = {
	ispath_abs,
	realpath,
	readdir,
	lstats,
	remove,
	write,
	info,
	read,
	copy
};
