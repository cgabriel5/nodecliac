"use strict";

const fs = require("fs");
const path = require("path");
const rimraf = require("rimraf");
const ext = require("file-extension");

/**
 * Wrapper for readFile method. Returns a Promise.
 *
 * @param  {string} p - The path of file to read.
 * @return {promise} - Promise is returned.
 */
let read = (p) => {
	return new Promise((resolve, reject) => {
		fs.readFile(p, (err, data) => {
			if (err) reject(err);
			resolve(data.toString());
		});
	});
};
/**
 * Wrapper for writeFile method. Returns a Promise.
 *
 * @param  {string} p - The path of file to read.
 * @param  {string} data - The file's contents.
 * @param  {number} mode - The file's mode (permission) value.
 * @return {promise} - Promise is returned.
 */
let write = (p, data, mode) => {
	return new Promise((resolve, reject) => {
		fs.writeFile(p, data, (err) => {
			// Apply file mode if supplied.
			if (mode) {
				// Using options.mode does not work as expected:
				// [https://github.com/nodejs/node/issues/1104]
				// [https://github.com/nodejs/node/issues/2249]
				// [https://github.com/nodejs/node-v0.x-archive/issues/25756]
				// [https://x-team.com/blog/file-system-permissions-umask-node-js/]

				// Apply file mode (chmod) explicitly.
				fs.chmod(p, mode, (err) => {
					if (err) reject(err);
					resolve(true);
				});
			} else {
				if (err) reject(err);
				resolve(true);
			}
		});
	});
};
/**
 * Wrapper for copyFile method. Returns a Promise.
 *
 * @param  {string} p - The path of file to copy.
 * @return {promise} - Promise is returned.
 *
 * @resource [https://stackoverflow.com/a/46253698]
 */
let copy = (p, destination) => {
	return new Promise((resolve, reject) => {
		fs.copyFile(p, destination, (err) => {
			if (err) reject(err);
			resolve(true);
		});
	});
};

/**
 * Wrapper for unlink method. Returns a Promise.
 *
 * @param  {string} p - The path of file to remove.
 * @return {promise} - Promise is returned.
 */
let remove = (p) => {
	return new Promise((resolve, reject) => {
		fs.unlink(p, (err) => {
			if (err) reject(err);
			resolve(true);
		});
	});
};

/**
 * Wrapper chmod method. Returns a Promise.
 *
 * @param  {string} p - The path of file to change mode.
 * @param  {number} mode - The file's mode (permission) value.
 * @return {promise} - Promise is returned.
 */
let chmod = (p, mode) => {
	return new Promise((resolve, reject) => {
		fs.chmod(p, mode, (err) => {
			if (err) reject(err);
			resolve(true);
		});
	});
};

/**
 * Get file path information (i.e. file name and directory path).
 *
 * @param  {string} p - The complete file path.
 * @return {object} - Object containing file path components.
 */
let info = (p) => {
	let extension = ext(p);
	let name = path.basename(p);
	let dirname = path.dirname(p);

	return {
		name,
		dirname,
		ext: extension,
		path: p
	};
};

/**
 * Wrapper for readdir method. Returns a Promise.
 *
 * @param  {string} p - The path of file to read.
 * @return {promise} - Promise is returned.
 */
let readdir = (p) => {
	return new Promise((resolve, reject) => {
		fs.readdir(p, (err, list) => {
			if (err) reject(err);
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
let ispath_abs = (p) => {
	return (
		path.isAbsolute(p) &&
		path.normalize(p + "/") === path.normalize(path.resolve(p) + "/")
	);
};

/**
 * Get file paths stats.
 *
 * @param  {string} p - The file path to use.
 * @return {object} - The file path's stats object.
 *
 * @resource [https://stackoverflow.com/a/15630832]
 * @resource [https://pubs.opengroup.org/onlinepubs/7908799/xsh/lstat.html]
 * @resource [https://www.brainbell.com/javascript/fs-stats-structure.html]
 */
let lstats = (p) => {
	return new Promise((resolve, reject) => {
		fs.lstat(p, (err, stats) => {
			if (err) reject(err);

			// Add other pertinent information to object:
			// [https://stackoverflow.com/a/15630832]
			// [https://stackoverflow.com/a/11287004]
			stats.is = {
				file: stats.isFile(),
				directory: stats.isDirectory(),
				blockdevice: stats.isBlockDevice(),
				characterdevice: stats.isCharacterDevice(),
				symlink: stats.isSymbolicLink(),
				fifo: stats.isFIFO(),
				socket: stats.isSocket()
			};

			resolve(stats);
		});
	});
};

/**
 * Checks if path exists.
 *
 * @param  {string} p - The path to use.
 * @return {boolean} - True if exists, else false.
 */
let exists = (p) => {
	return new Promise((resolve /*, reject*/) => {
		fs.lstat(p, (err /*, stats*/) => resolve(!err));
	});
};
/**
 * Checks if file path exists.
 *
 * @param  {string} p - The path to use.
 * @return {boolean} - True if exists, else false.
 */
let fexists = (p) => {
	return new Promise((resolve /*, reject*/) => {
		fs.lstat(p, (err, stats) => resolve(!err && stats.isFile()));
	});
};
/**
 * Checks if directory path exists.
 *
 * @param  {string} p - The path to use.
 * @return {boolean} - True if exists, else false.
 */
let dexists = (p) => {
	return new Promise((resolve /*, reject*/) => {
		fs.lstat(p, (err, stats) => resolve(!err && stats.isDirectory()));
	});
};
/**
 * Checks if symlink path exists.
 *
 * @param  {string} p - The path to use.
 * @return {boolean} - True if exists, else false.
 */
let lexists = (p) => {
	return new Promise((resolve /*, reject*/) => {
		fs.lstat(p, (err, stats) => resolve(!err && stats.isSymbolicLink()));
	});
};

/**
 * Checks if user has access (permission) to access path.
 *
 * @param  {string} p - The path to use.
 * @return {boolean} - True if yes, else false.
 */
let access = (p) => {
	return new Promise((resolve, reject) => {
		fs.access(p, fs.constants.F_OK, (err) => {
			if (err) reject(err);
			resolve(true);
		});
	});
};

/**
 * Resolve paths `real` path. This means solving symlinks.
 *
 * @param  {string} p - The file path to use.
 * @return {string} - The resolved real path.
 *
 * @resource [https://nodejs.org/docs/latest/api/fs.html#fs_fs_realpath_path_options_callback]
 */
let realpath = (p) => {
	return new Promise((resolve, reject) => {
		fs.realpath(p, (err, resolved_path) => {
			if (err) reject(err);
			resolve(resolved_path);
		});
	});
};

/**
 * Wrapper for rimraf module.
 *
 * @param  {string} p - The path to delete.
 * @return {promise} - rimraf promise.
 */
let rmrf = (p) => {
	return new Promise((resolve, reject) => {
		rimraf(p, (err) => {
			if (err) reject(err);
			resolve(true);
		});
	});
};

/**
 * Use provided path to build the file's correct source path.
 *
 * @param  {string} p - The source's file path.
 * @return {string} - The corrected source's file path.
 */
// let fixpath = p => { return path.join(path.dirname(__dirname), p); };

module.exports = {
	ispath_abs,
	realpath,
	readdir,
	lstats,
	remove,
	write,
	info,
	read,
	rmrf,
	copy,
	exists,
	fexists,
	dexists,
	lexists,
	access,
	chmod
};
