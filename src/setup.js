"use strict";

// Needed modules.
const fs = require("fs");
const path = require("path");
const chalk = require("chalk");
const log = require("fancy-log");
const mkdirp = require("mkdirp");
const fe = require("file-exists");
const { paths } = require("./utils.js");

module.exports = () => {
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
		bashrcpath,
		mainscriptname,
		mscriptpath,
		acscriptpath,
		acplscriptpath,
		acplscriptconfigpath,
		acmapspath,
		acmapssource
	} = paths;

	// .bashrc file needs to exist to do anything.
	fe(bashrcpath, (err, exists) => {
		if (err) {
			console.error(err);
			process.exit();
		}

		// If .bashrc does not exist, give message and end process.
		if (!exists) {
			log(`${chalk.bold(".bashrc")} file does not exist. Setup aborted.`);
			process.exit();
		}

		// Create ~/.nodecliac/defs/ path.
		mkdirp(acmapspath, function(err) {
			if (err) {
				console.error(err);
				process.exit();
			}

			// Create ~/.nodecliac/src/ path.
			mkdirp(acmapssource, function(err) {
				if (err) {
					console.error(err);
					process.exit();
				}

				// Get .bashrc script contents.
				let contents = fs.readFileSync(bashrcpath).toString();

				// Check for nodecliac marker.
				if (!/^ncliac=~/m.test(contents)) {
					// Edit .bashrc file to "include" nodecliac main script file.
					fs.writeFileSync(
						bashrcpath,
						`${contents}\nncliac=~/.nodecliac/src/${mainscriptname};if [ -f "$ncliac" ];then source "$ncliac";fi;`
					);
				}

				// Generate main and completion scripts.
				script("scripts/ac.sh", acscriptpath);
				script("scripts/main.sh", mscriptpath);
				script("scripts/ac.pl", acplscriptpath, "775");
				script("scripts/config.pl", acplscriptconfigpath, "775");

				// Give success message.
				log(chalk.green("Setup successful."));
			});
		});
	});
};
