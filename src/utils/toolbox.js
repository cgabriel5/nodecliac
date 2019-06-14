"use strict";

// Needed modules.
const { concat } = require("./sets.js");
const { checksum } = require("./checksum.js");
const { exit } = require("./exit.js");
const { paths } = require("./paths.js");
const { strip_comments } = require("./text.js");
const { readdir, remove, write, info, read } = require("./filesystem.js");

module.exports = {
	strip_comments,
	checksum,
	concat,
	paths,
	exit,
	readdir,
	remove,
	write,
	info,
	read
};
