#!/usr/bin/env node

"use strict";

const chalk = require("chalk");
const minimist = require("minimist");
const { exit, fmt } = require("./utils/toolbox.js");

const args = minimist(process.argv.slice(2));
let [action] = args._;

// Allowed actions.
const ac_main = ["make", "format", "test", "debug", "bin"];
const ac_mis = ["print", "setup", "status", "registry", "uninstall", "cache"];
const ac_pkg = ["add", "remove", "link", "unlink", "enable", "disable"];
const actions = ac_main.concat(ac_mis, ac_pkg);

if (action) {
	let tstring = "Unknown command ?.";
	if (!actions.includes(action)) exit([fmt(tstring, chalk.bold(action))]);
	require(`./actions/${action}.js`)(args);
} else {
	if (args.version) console.log(require("../package.json").version);
}
