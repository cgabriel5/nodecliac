#!/usr/bin/env node

"use strict";

const chalk = require("chalk");
const minimist = require("minimist");
const { exit, fmt } = require("./utils/toolbox.js");

const args = minimist(process.argv.slice(2)); // Get CLI parameters.
let [action] = args._; // Get the provided action to run.
// Allowed actions.
const actions = [
	"make",
	"format",
	"print",
	"setup",
	"status",
	"registry",
	"uninstall"
];

// Run action's respective file if provided.
if (action) {
	// Check if command exists.
	let tstring = "Unknown command ?.";
	if (!actions.includes(action)) exit([fmt(tstring, chalk.bold(action))]);
	if (action === "format") action = "make"; // Reset format to make action.
	require(`./actions/${action}.js`)(args); // Run action script.
} else {
	// If version flag supplied, show version.
	if (args.version) console.log(require("../package.json").version);
}
