"use strict";

const path = require("path");
const hdir = require("os").homedir();

/**
 * Collapse starting home dir in a path to '~'.
 *
 * @param  {string} p - The path.
 * @return {undefined} - Nothing is returned.
 */
let shrink = (p) => {
	return p.startsWith(hdir) ? path.join("~", p.slice(hdir.length)) : p;
};

/**
 * Expand starting '~' in a path.
 *
 * @param  {string} p - The path.
 * @return {undefined} - Nothing is returned.
 */
let expand = (p) => (p.startsWith("~") ? path.join(hdir, p.slice(1)) : p);

module.exports = { shrink, expand };
