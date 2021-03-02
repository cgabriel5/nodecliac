"use strict";

const os = require("os");
const path = require("path");
const chalk = require("chalk");
const fe = require("file-exists");
const de = require("directory-exists");
const toolbox = require("../utils/toolbox.js");
const { paths, readdir, lstats, realpath } = toolbox;

module.exports = async () => {
	let { registrypath } = paths;
	let files = [];

	// Maps path needs to exist to list acdef files.
	if (!(await de(registrypath))) process.exit();

	// Get list of directory command folders.
	let commands = await readdir(registrypath);
	let count = commands.length;

	console.log(chalk.bold.blue(registrypath)); // Print header.

	// Exit if directory is empty.
	if (!count) {
		if (count === 1) console.log(`\n${count} package`);
		else console.log(`\n${count} packages`);
		process.exit();
	}

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
		if (await fe(acdefpath)) check = true;
		if ((await fe(configpath)) && check) data.hasacdefs = true;

		// Check whether it's a symlink.
		let pkgpath = `${registrypath}/${command}`;
		let res = await lstats(pkgpath);
		data.isdir = res.is.directory;
		if (res.is.symlink) {
			data.issymlink = true;
			let resolved_path = await realpath(pkgpath);
			data.realpath = resolved_path;

			let res = await lstats(resolved_path);
			data.issymlinkdir = res.is.directory;
			if (res.is.directory) data.isdir = true;

			// Confirm symlink dir gave .acdefs.
			let sympath = path.join(resolved_path, command, filename);
			let sympathconf = path.join(resolved_path, command, configfilename);

			check = false;
			if (await fe(sympath)) check = true;
			if ((await fe(sympathconf)) && check) data.issymlink_valid = true;
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
						console.log(`${decor}${dcommand}/`);
					} else {
						console.log(`${decor}${rcommand}`);
					}
				} else {
					if (issymlinkdir) {
						let color = issymlink_valid ? "blue" : "red";
						let linkdir = `${chalk.bold[color](realpath)}`;
						console.log(`${decor}${ccommand} -> ${linkdir}/`);
					} else {
						console.log(`${decor}${ccommand} -> ${realpath}`);
					}
				}
			});
	}

	if (count === 1) console.log(`\n${count} package`);
	else console.log(`\n${count} packages`);
};
