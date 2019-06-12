"use strict";

// Needed modules.
const fs = require("fs");
const path = require("path");
const chalk = require("chalk");
const log = require("fancy-log");
const mkdirp = require("mkdirp");
const fe = require("file-exists");
const copydir = require("recursive-copy");
const de = require("directory-exists");
const { exit, paths } = require("../utils/main.js");

module.exports = args => {
	// Get CLI args.
	let { force, rcfilepath, commands } = args;

	// If command value is provided it must be a string list.
	if (commands && typeof commands !== "string") {
		exit([`${chalk.bold("--commands")} needs to be a string list.`]);
	}

	/**
	 * Generate bash script from source file and remove comments/empty lines.
	 *
	 * @param  {string} source - The script's source path.
	 * @param  {string} output - The script's output path.
	 * @param  {string} mode - The script's mode (chmod) value.
	 * @return {string} - The cleaned file contents.
	 */
	let script = (source, output, mode) => {
		// Write file to disk.
		fs.writeFileSync(
			output,
			fs
				// Get source file.
				.readFileSync(path.join(__dirname, source))
				.toString()
				// Inject acmap.
				// .replace(/# \[\[__acmap__\]\]/, acmap)
				// Remove comments/empty lines but leave sha-bang comment.
				.replace(/^\s*#(?!!).*?$/gm, "")
				.replace(/\s{1,}#\s{1,}.+$/gm, "")
				// .replace(/(^\s*#.*?$|\s{1,}#\s{1,}.*$)/gm, "")
				.replace(/(\r\n\t|\n|\r\t){1,}/gm, "\n")
				.trim()
		);

		// Apply file mode if supplied.
		if (mode) {
			// Using options.mode does not work as expected:
			// [https://github.com/nodejs/node/issues/1104]
			// [https://github.com/nodejs/node/issues/2249]
			// [https://github.com/nodejs/node-v0.x-archive/issues/25756]
			// [https://x-team.com/blog/file-system-permissions-umask-node-js/]

			// Therefore apply file mode (chmod) explicitly.
			fs.chmodSync(output, mode);
		}
	};

	// Get needed paths.
	let {
		customdir,
		bashrcpath,
		mainscriptname,
		mscriptpath,
		acscriptpath,
		acplscriptpath,
		acplscriptconfigpath,
		acmapspath,
		acmapssource,
		acmapsresources,
		setupfilepath
	} = paths;

	// If a custom .rcfile path was provided use that instead.
	if (rcfilepath) {
		bashrcpath = rcfilepath;
	}

	// If ~/.nodecliac exist we need the --force flag to proceed with install.
	de(customdir, (err, exists) => {
		// If custom directory exists exit setup and give user a warning.
		if (exists && !force) {
			exit([
				`${chalk.bold(customdir)} exists. Setup with ${chalk.bold(
					"--force"
				)} to overwrite directory.`
			]);
		}

		// .rcfile needs to exist to do anything.
		fe(bashrcpath, (err, exists) => {
			if (err) {
				console.error(err);
				process.exit();
			}

			// If .rcfile does not exist, give message and end process.
			if (!exists) {
				log(
					`${chalk.bold(
						rcfilepath
					)} file does not exist. Setup aborted.`
				);
				process.exit();
			}

			// Create ~/.nodecliac/defs/ path.
			mkdirp(acmapspath, function(err) {
				if (err) {
					console.error(err);
					process.exit();
				}

				// Prep allowed commands list.
				commands = commands ? commands.split(/( |,)/) : [];
				// Ensure nodecliac.acdef is copied over.
				let allowed_commands = ["nodecliac"].concat(commands);

				// Add nodecliac and other supplied command files to registry.
				copydir(
					// Copy nodecliac resources acdef files...
					paths.resourcedefs,
					// ...to nodecliac registry location.
					paths.acmapspath,
					{
						overwrite: true,
						dot: true,
						debug: false,
						filter: function(filename) {
							// Get command from filename.
							let command = (filename
								.replace(/^\./, "")
								.split(".", 1) || [])[0];

							// File must pass conditions to be copied.
							return (
								path.extname(filename) === ".acdef" &&
								// Command must be allowed to be copied.
								allowed_commands.includes(command)
							);
						}
					},
					function(err) {
						// Exit on error.
						if (err) {
							exit([
								`Failed to copy .acdef files to ${chalk.bold(
									paths.acmapspath
								)}.`
							]);
						}

						// Create ~/.nodecliac/src/ path.
						mkdirp(acmapssource, function(err) {
							if (err) {
								console.error(err);
								process.exit();
							}

							// Create ~/.nodecliac/resources/ path.
							mkdirp(acmapsresources, function(err) {
								if (err) {
									console.error(err);
									process.exit();
								}

								// Get .rcfile script contents.
								let contents = fs
									.readFileSync(bashrcpath)
									.toString();

								// Check for nodecliac marker.
								if (!/^ncliac=~/m.test(contents)) {
									// Edit .rcfile file to "include" nodecliac main script file.
									fs.writeFileSync(
										bashrcpath,
										`${contents.replace(
											/\n*$/g,
											""
										)}\n\nncliac=~/.nodecliac/src/${mainscriptname};if [ -f "$ncliac" ];then source "$ncliac";fi;`
									);
								}

								// Generate main and completion scripts.
								script("scripts/ac.sh", acscriptpath);
								script("scripts/main.sh", mscriptpath);
								script("scripts/ac.pl", acplscriptpath, "775");
								script(
									"scripts/config.pl",
									acplscriptconfigpath,
									"775"
								);

								// Create setup info file to reference on uninstall.
								fs.writeFileSync(
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
								);

								// Give success message.
								log(chalk.green("Setup successful."));
							});
						});
					}
				);
			});
		});
	});
};
