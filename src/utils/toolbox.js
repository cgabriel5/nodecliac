"use strict";

const md5 = require("./md5.js");
const { concat } = require("./sets.js");
const { checksum } = require("./checksum.js");
const { exit } = require("./exit.js");
const { paths } = require("./paths.js");
const { strip_comments } = require("./text.js");
const { hasProp } = require("./objects.js");
const { fmt, rtp } = require("./strings.js");
const fs = require("./filesystem.js");
const { realpath, readdir, lstats, remove } = fs;
const { write, info, read, copy, rmrf, ispath_abs, exists } = fs;
const { fexists, dexists, lexists, access, chmod } = fs;

module.exports = {
	exists,
	fexists,
	dexists,
	lexists,
	access,
	chmod,
	hasProp,
	strip_comments,
	checksum,
	concat,
	paths,
	exit,
	md5,
	ispath_abs,
	realpath,
	lstats,
	readdir,
	remove,
	write,
	info,
	read,
	copy,
	rmrf,
	fmt,
	rtp
};
