#!/usr/bin/env node

"use strict";

// Needed modules.
const chalk = require("chalk");
const minimist = require("minimist");
const { exit } = require("./utils/toolbox.js");

// Get CLI parameters.
const args = minimist(process.argv.slice(2));
// Get the provided action to run.
let [action] = args._;
// Allowed actions.
const actions = [
	"setup",
	"uninstall",
	"list",
	"make",
	"remove",
	"add",
	"status",
	"print",
	"format"
];

// Run action's respective file if provided.
if (action) {
	// // Check if action was supplied.
	// if (!action) {
	// 	exit([`A action was not provided.`]);
	// }
	// Check if command exists.
	if (!actions.includes(action)) {
		exit([`Supplied unknown command ${chalk.bold(action)}.`]);
	}

	// If action is 'format' switch to 'make'.
	if (action === "format") {
		action = "make";
	}

	require(`./actions/${action}.js`)(args);
} else {
	// If version flag supplied, show version.
	if (args.version) {
		console.log(require("../package.json").version);
	}
}
