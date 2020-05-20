"use strict";

const os = require("os");
const path = require("path");
const chalk = require("chalk");
const flatry = require("flatry");
const log = require("fancy-log");
const de = require("directory-exists");
const fe = require("file-exists");
const toolbox = require("../utils/toolbox.js");
const { paths, readdir, lstats, realpath } = toolbox;

module.exports = async () => {
	let { registrypath } = paths;
	let files = [];
	// eslint-disable-next-line no-unused-vars
	let err, res, commands;

	// Maps path needs to exist to list acdef files.
	[err, res] = await flatry(de(registrypath));
	if (!res) process.exit();

	// Get list of directory command folders.
	[err, commands] = await flatry(readdir(registrypath));
	let count = commands.length;

	console.log(`${chalk.bold(registrypath)} (${count})`); // Print header.

	if (!count) process.exit(); // Exit if directory is empty.

	// Loop over folders to get .acdef files.
	for (let i = 0, l = count; i < l; i++) {
		let command = commands[i];

		let filename = `${command}.acdef`;
		let configfilename = `.${command}.config.acdef`;
		let acdefpath = path.join(registrypath, command, filename);
		let configpath = path.join(registrypath, command, configfilename);

		let data = {
			command,
			isdir: false,
			hasacdefs: false,
			issymlink: false,
			issymlinkdir: false,
			realpath: "",
			issymlink_valid: false
		};
		let check;

		check = false;
		[err, res] = await flatry(fe(acdefpath));
		if (res) check = true;
		[err, res] = await flatry(fe(configpath));
		if (res && check) data.hasacdefs = true;

		// Check whether it's a symlink.
		let pkgpath = `${registrypath}/${command}`;
		[err, res] = await flatry(lstats(pkgpath));
		data.isdir = res.is.directory;

		if (res.is.symlink) {
			data.issymlink = true;
			[err, res] = await flatry(realpath(pkgpath));
			let resolved_path = res;
			data.realpath = resolved_path;

			[err, res] = await flatry(lstats(resolved_path));
			data.issymlinkdir = res.is.directory;
			if (res.is.directory) data.isdir = true;

			// Confirm symlink dir gave .acdefs.
			let sympath = path.join(resolved_path, command, filename);
			let sympathconf = path.join(resolved_path, command, configfilename);

			check = false;
			[err, res] = await flatry(fe(sympath));
			if (res) check = true;
			[err, res] = await flatry(fe(sympathconf));
			if (res && check) data.issymlink_valid = true;
		}

		files.push(data);
	}

	// List commands.
	if (files.length) {
		files
			.sort(function (a, b) {
				return a.command.localeCompare(b.command);
			})
			.forEach(async function (data, i) {
				let { command, isdir, hasacdefs, issymlink } = data;
				let { issymlinkdir, realpath, issymlink_valid } = data;

				// Remove user name from path.
				let homedir = os.homedir();
				realpath = realpath.replace(new RegExp("^" + homedir), "~");

				// Decorate commands.
				let bcommand = chalk.bold.blue(command);
				let ccommand = chalk.bold.cyan(command);
				let rcommand = chalk.bold.red(command);
				// Row decor.
				let decor = count !== i + 1 ? "├── " : "└── ";

				if (!issymlink) {
					if (isdir) {
						let dcommand = hasacdefs ? bcommand : rcommand;
						log(`${decor}${dcommand}/`);
					} else {
						log(`${decor}${rcommand}`);
					}
				} else {
					if (issymlinkdir) {
						let color = issymlink_valid ? "blue" : "red";
						let linkdir = `${chalk.bold[color](realpath)}`;
						log(`${decor}${ccommand} -> ${linkdir}/`);
					} else {
						log(`${decor}${ccommand} -> ${realpath}`);
					}
				}
			});
	}
};
