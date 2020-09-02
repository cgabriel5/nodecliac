"use strict";

const fe = require("file-exists");
const { lstats } = require("../utils/toolbox.js");
const { paths, write, read } = require("../utils/toolbox.js");
const root = paths.ncliacdir;
const config = `${root}/.config`;
const lookup = { status: 0, cache: 1, debug: 2, singletons: 3 };

// Config settings:
// [1] status (disabled)
// [2] cache
// [3] debug
// [4] singletons

/**
 * Create config file if it's empty or does not exist yet.
 *
 * @return {undefined} - Nothing is returned.
 */
let initconfig = async () => {
	if (!(await fe(config))) await write(config, "1101");
	let stats = await lstats(config);
	if (!stats["size"]) await write(config, "1101");
};

/**
 * Returns config setting.
 *
 * @param  {string} setting - The setting name.
 * @return {undefined} - Nothing is returned.
 */
let getsetting = async (setting) => {
	let cstring = await read(config);
	return cstring.charAt(lookup[setting]);
};

/**
 * Sets the config setting.
 *
 * @param  {string} setting - The setting name.
 * @param  {string} value - The setting's value.
 * @return {undefined} - Nothing is returned.
 */
let setsetting = async (setting, value) => {
	const i = lookup[setting];
	let cstring = await read(config);
	cstring = cstring.substr(0, i) + value + cstring.substr(i + 1);
	await write(config, cstring.trim());
};

module.exports = { initconfig, setsetting, getsetting };
