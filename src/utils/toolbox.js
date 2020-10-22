"use strict";

const md5 = require("./md5.js");
const aexec = require("./aexec.js");
const { concat } = require("./sets.js");
const { checksum } = require("./checksum.js");
const { exit } = require("./exit.js");
const { paths } = require("./paths.js");
const { strip_comments, strip_trailing_slash } = require("./text.js");
const { hasProp } = require("./objects.js");
const { fmt, rtp } = require("./strings.js");
const fs = require("./filesystem.js");
const tilde = require("./tilde.js");
const { realpath, readdir, lstats, remove } = fs;
const { write, info, read, copy, rmrf, ispath_abs, exists } = fs;
const { fexists, dexists, lexists, access, chmod } = fs;
const { shrink, expand } = tilde;

module.exports = {
	shrink,
	expand,
	aexec,
	exists,
	fexists,
	dexists,
	lexists,
	access,
	chmod,
	hasProp,
	strip_comments,
	strip_trailing_slash,
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
