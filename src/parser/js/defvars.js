#!/usr/bin/env node

"use strict";

function platform() {
	let platform = process.platform;
	if (platform === "darwin") platform = "macosx";
	if (platform === "win32") platform = "windows";
	return platform;
}

// Builtin variables.
function builtins(cmdname) {
	return {
		HOME: require("os").homedir(),
		OS: platform(),
		COMMAND: cmdname,
		PATH: `~/.nodecliac/registry/${cmdname}`
	};
}

module.exports = { builtins };
