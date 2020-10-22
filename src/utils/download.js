"use strict";

const fs = require("fs");
const url = require("url");
const path = require("path");
const flatry = require("flatry");
const { http, https } = require("follow-redirects");
const hdir = require("os").homedir();

let arch = process.arch;
let platform = process.platform;
let version = process.version.slice(1);
// [https://github.com/node-modules/default-user-agent]
// [https://stackoverflow.com/a/21384582]
let agent = `node.js/${version} (${platform};${arch})`;

/**
 * Downloads URL resource at provided destination. Returns a Promise.
 *
 * @param  {string} r - The URL resource to download.
 * @param  {string} dest - The save/output destination.
 * @param  {string} cb - Optional callback.
 * @return {promise} - Promise is returned.
 *
 * @resource [https://stackoverflow.com/a/62056725]
 * @resource [https://stackoverflow.com/a/32134846]
 * @resource [http://syskall.com/how-to-follow-http-redirects-in-node-dot-js/]
 */
let download = () => {};

download.str = (uri, options = {}) => {
	let content = "";
	let result = { err: false, res: {}, str: "" };
	let proto = uri.includes("https") ? https : http;
	let opts = { headers: { "user-agent": agent } };
	options = Object.assign(opts, options);

	return new Promise((resolve, reject) => {
		// [https://stackoverflow.com/a/5801654]
		let req = proto.request(uri, options, function (res) {
			if (res.statusCode !== 200) {
				result.err = true;
				result.res = res;
				return reject(result);
			}
			res.setEncoding("utf8");
			res.on("data", function (chunk) {
				content += chunk;
			});
			res.on("end", function () {
				result.str = content;
				result.res = res;
				resolve(result);
			});
			req.on("error", (err) => {
				result.err = true;
				result.res = err;
				reject(result);
			});
		});
		req.end();
	});
};

download.file = (uri, dest, name, options = {}) => {
	let proto = uri.includes("https") ? https : http;
	let result = { err: false, res: {}, dest: "" };
	let opts = { headers: { "user-agent": agent } };
	options = Object.assign(opts, options);

	return new Promise((resolve, reject) => {
		fs.lstat(dest, (err, stats) => {
			// [https://stackoverflow.com/a/27006391]
			let parsed = url.parse(uri);
			name = name || path.basename(parsed.pathname) || "dl-" + Date.now();
			dest = path.join(dest, name);

			let file = fs.createWriteStream(dest);
			let response;

			if (!err && stats.isDirectory()) {
				let req = proto.get(uri, options, (res) => {
					response = res;
					if (res.statusCode !== 200) {
						result.err = true;
						result.res = res;
						result.des = dest;
						return reject(result);
					}
					res.pipe(file);
				});

				// The destination stream is ended by the time it's called
				file.on("finish", () => {
					result.dest = dest;
					result.res = response;
					resolve(result);
				});
				req.on("error", (err) =>
					fs.unlink(dest, () => {
						result.err = true;
						result.res = err;
						resolve(result);
					})
				);
				file.on("error", (err) =>
					fs.unlink(dest, () => {
						result.err = true;
						result.res = err;
						resolve(result);
					})
				);
				req.end();
			} else {
				result.err = true;
				result.res = err;
				return reject(result);
			}
		});
	});
};

module.exports = download;

// // Usage example:
// (async () => {
// 	let err, res;
// 	[err, res] = await flatry(download.str("https://raw.githubusercontent.com/cgabriel5/nodecliac/master/install.sh"));
// 	[err, res] = await flatry(download.str("https://api.github.com/repos/cgabriel5/nodecliac/branches/master"));
// 	console.log(err, res.str);
// 	let dest = path.join(hdir, "Downloads");
// 	let name = Date.now() + "_nodecliac.tar.gz";
// 	[err, res] = await flatry(download.file("https://api.github.com/repos/cgabriel5/nodecliac/tarball", dest, name));
// })();
