"use strict";

const shell = require("shelljs");

/**
 * Wrapper function which promisifies the shell.exec function.
 *
 * @param  {string} cmd - The command to execute.
 * @param  {object} opts - The options object.
 * @param  {function} callback - The callback function.
 * @return {promise} - The wrapped promise.
 *
 * @resource [https://gist.github.com/davidrleonard/2962a3c40497d93c422d1269bcd38c8f]
 */
module.exports = (cmd, opts = {} /*, callback*/) => {
	// let callback = (/*code, stdout, stderr*/) => {};
	return new Promise((resolve, reject) => {
		shell.exec(cmd, opts, (code, stdout, stderr) => {
			if (/*code !== 0* || */ stderr) return reject(stderr);
			return resolve(stdout);
		});
	});
};
