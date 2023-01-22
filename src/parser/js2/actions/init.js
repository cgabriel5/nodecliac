"use strict";

const path = require("path");
const chalk = require("chalk");
const mkdirp = require("make-dir");
const de = require("directory-exists");
const stripansi = require("strip-ansi");
const toolbox = require("../utils/toolbox.js");
const { write, exit, fmt, prompt, aexec, shrink } = toolbox;
const hdir = require("os").homedir();

module.exports = async (args) => {
	let { force } = args;
	let { start, end, input } = prompt;
	let cwd = process.cwd();

	let init = async (restart) => {
		start();
		if (restart) console.log();

		// prettier-ignore
		console.log(`${chalk.bold.blue("Info:")} nodecliac completion package initialization.`);

		let command = "";
		let padding = "";
		let def = chalk.italic.bold.cyan("default");
		let pprefix = padding + chalk.bold.magenta("Prompt:");
		let aprefix = padding + chalk.bold.green("Answer:");

		/**
		 * Print reply/response.
		 *
		 * @param  {string} reply - The provided reply.
		 * @return {undefined} - Nothing is returned.
		 */
		let preply = (reply) => console.log(`${aprefix} ${chalk.bold(reply)}`);

		// prettier-ignore
		while (!command) {
			command = await input(`${pprefix} [1/6] Completion package command (${chalk.yellow("required")}): `);
			// Clear line on empty response.
			if (!command) await aexec("tput cuu 1 && tput el");
		}
		command = command.trim();

		// Check for existing same name completion package.
		let pkgpath = path.join(cwd, command);
		let spkgpath = shrink(pkgpath);
		if (!force && (await de(pkgpath))) {
			// prettier-ignore
			exit([`${chalk.bold.red("Error:")} Directory ${chalk.bold(command)} already exists at:`, `... ${spkgpath}`,`${chalk.bold.blue("Tip:")} Run with --force flag to overwrite existing folder.`]);
		}

		preply(command);
		// prettier-ignore
		let author = await input(`${pprefix} [2/6] Author (GitHub username or real name): `, "");
		preply(author);
		// prettier-ignore
		let version = await input(`${pprefix} [3/6] Version [${def} 0.0.1]: `, "0.0.1");
		preply(version);
		let des_def = `Completion package for ${command}`;
		// prettier-ignore
		let description = await input(`${pprefix} [4/6] Description [${def} ${des_def}]: `, des_def);
		preply(description);
		// prettier-ignore
		let license = await input(`${pprefix} [5/6] Project license [${def} MIT]: `, "MIT");
		preply(license);
		// prettier-ignore
		let repo = await input(`${pprefix} [6/6] Github repo: (i.e. username/repository) `, "");
		preply(repo);

		let content = `${chalk.magenta("[Package]")}
name = "${command}"
version = "${version}"
description = "${description}"
license = "${license}"

${chalk.magenta("[Author]")}
name = "${author}"
repo = "${repo}"`;

		console.log();
		// prettier-ignore
		console.log(`${chalk.bold.blue("Info:")} package.ini will contain the following:`);
		console.log();
		console.log(content);

		console.log();
		// prettier-ignore
		console.log(`${chalk.bold.blue("Info:")} Completion package base structure:`);
		console.log();
		let tree = `${spkgpath}
├── ${command}.acmap
├── ${command}.acdef
├── .${command}.config.acmap
└── package.ini`;
		console.log(tree);
		console.log();

		let confirmation = "";
		// prettier-ignore
		let allowed = ["y", "yes", "c", "cancel", "n", "no", "r", "restart"];
		while (!-~allowed.indexOf(confirmation.toLowerCase())) {
			confirmation = await input(
				`${pprefix} Looks good, create package? [${chalk.italic.bold.cyan(
					"default"
				)} ${chalk.bold.cyan("y")}]es, [c]ancel, [r]estart: `,
				"y"
			);
			// Clear line on empty response.
			if (!-~allowed.indexOf(confirmation.toLowerCase())) {
				await aexec("tput cuu 1 && tput el");
			}
		}

		confirmation = confirmation[0].toLowerCase();
		preply(confirmation);
		prompt.close();
		if (confirmation === "y") {
			// Create basic completion package for command.
			await mkdirp(pkgpath);
			let pkginipath = path.join(pkgpath, "package.ini");
			let acmappath = path.join(pkgpath, `${command}.acmap`);
			let acdefpath = path.join(pkgpath, `${command}.acdef`);
			let configpath = path.join(pkgpath, `.${command}.config.acmap`);
			await write(pkginipath, stripansi(content), 0o775);
			await write(acmappath, "", 0o775);
			await write(acdefpath, "", 0o775);
			await write(configpath, "", 0o775);
			console.log();
			// prettier-ignore
			console.log(`${chalk.bold.blue("Info:")} completion packaged created at:`);
			console.log(`... ${shrink(pkgpath)}`);
		} else if (confirmation === "c") {
			// prettier-ignore
			exit(["", `${chalk.bold.blue("Info:")} Completion package initialization cancelled.`]);
		} else if (confirmation === "r") return init(true);
	};

	init();
};
