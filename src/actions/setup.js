"use strict";

// Needed modules.
const fs = require("fs");
const path = require("path");
const chalk = require("chalk");
const flatry = require("flatry");
const log = require("fancy-log");
const mkdirp = require("make-dir");
const fe = require("file-exists");
const copydir = require("recursive-copy");
const de = require("directory-exists");
const { exit, paths } = require("../utils/main.js");
const { read, write, strip_comments } = require("../utils/file.js");

module.exports = async args => {
	/**
	 * Use provided path to build the file's correct source path.
	 *
	 * @param  {string} filepath - The source's file path.
	 * @return {string} - The corrected source's file path.
	 */
	let fixpath = filepath => {
		return path.join(path.dirname(__dirname), filepath);
	};

	// Get CLI args.
	let { force, rcfilepath, commands } = args;

	// If command value is provided it must be a string list.
	if (commands && typeof commands !== "string") {
		exit([`${chalk.bold("--commands")} needs to be a string list.`]);
	}

	// Get needed paths.
	let {
		customdir,
		bashrcpath,
		mainscriptname,
		mscriptpath,
		acscriptpath,
		acplscriptpath,
		acplscriptconfigpath,
		commandspaths,
		acmapssource,
		acmapsresources,
		resourcespath,
		setupfilepath
	} = paths;

	// If a custom .rcfile path was provided use that instead.
	if (rcfilepath) {
		bashrcpath = rcfilepath;
	}

	// Declare empty variables to reuse for all await operations.
	let err, res;

	// If ~/.nodecliac exists force flag is needed to overwrite current install.
	[err, res] = await flatry(de(customdir));
	if (res && !force) {
		exit([
			`${chalk.bold(customdir)} exists. Setup with ${chalk.bold(
				"--force"
			)} to overwrite directory.`
		]);
	}

	// If .rcfile does not exist, give message and end process.
	[err, res] = await flatry(fe(bashrcpath));
	if (!res) {
		exit([`${chalk.bold(bashrcpath)} file does not exist. Setup aborted.`]);
	}

	// Create needed paths
	[err, res] = await flatry(
		// [https://github.com/scopsy/await-to-js/issues/12#issuecomment-386147783]
		Promise.all([
			mkdirp(commandspaths), // ~/.nodecliac/commands/
			mkdirp(acmapssource) // ~/.nodecliac/src/
		])
	);

	// Get .rcfile script contents.
	[err, res] = await flatry(read(bashrcpath));

	// Check for nodecliac marker.
	if (!/^ncliac=~/m.test(res)) {
		// Edit .rcfile file to "include" nodecliac main script file.
		await flatry(
			write(
				bashrcpath,
				`${res.replace(
					/\n*$/g,
					""
				)}\n\nncliac=~/.nodecliac/src/${mainscriptname};if [ -f "$ncliac" ];then source "$ncliac";fi;`
			)
		);
	}

	// Generate needed completion scripts.
	[err, res] = await flatry(
		Promise.all([
			// Get script file contents.
			read(fixpath("scripts/ac.sh")),
			read(fixpath("scripts/main.sh")),
			read(fixpath("scripts/ac.pl")),
			read(fixpath("scripts/config.pl"))
		])
	);
	// Get each file contents from read results.
	let [acbash, maincontent, acpl, config] = res;

	// Create script files.
	[err, res] = await flatry(
		Promise.all([
			write(acscriptpath, strip_comments(acbash)),
			write(mscriptpath, strip_comments(maincontent)),
			write(acplscriptpath, strip_comments(acpl), "755"),
			write(acplscriptconfigpath, strip_comments(config), "755")
		])
	);

	// Create setup info file to reference on uninstall.
	[err, res] = await flatry(
		write(
			setupfilepath,
			JSON.stringify(
				{
					force: force || false,
					rcfilepath: bashrcpath,
					time: Date.now()
				},
				undefined,
				"\t"
			)
		)
	);

	// // Prep allowed commands list.
	// commands = commands ? commands.split(/( |,)/) : [];
	// // Ensure nodecliac.acdef is copied over.
	// let allowed_commands = ["nodecliac"].concat(commands);

	// Copy nodecliac command packages/files to nodecliac registry.
	[err, res] = await flatry(
		copydir(resourcespath, commandspaths, {
			// Copy options.
			overwrite: true,
			dot: true,
			debug: false,
			filter: function(filename) {
				// Get command from filename.
				// let command = (filename.replace(/^\./, "").split(".", 1) ||
				// [])[0];

				// File must pass conditions to be copied.
				return (
					// Don't copy acmaps directory/files.
					!/^__acmaps__/.test(filename)
					// Command must be allowed to be copied.
					// && allowed_commands.includes(command)
				);
			}
		})
	);
	// If copying fails give error.
	if (err) {
		exit(["Failed to copy command files."]);
	}

	// Give success message.
	log(chalk.green("Setup successful."));
};
