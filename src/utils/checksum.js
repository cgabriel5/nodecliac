"use strict";

const crypto = require("crypto");

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
	checksum
};
