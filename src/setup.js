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
	 * @return {string} - The cleaned file contents.
	 */
	let script = (source, output) => {
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
				if (!contents.includes("[nodecliac]")) {
					let decor_top = "#".repeat(88);
					let decor_bottom = decor_top.slice(1);
					let bash_edit = `# [nodecliac] ${decor_top}\nnodecliacpath=~/.nodecliac/src/${mainscriptname}; if [ -f "$nodecliacpath" ]; then source "$nodecliacpath"; fi #\n${decor_bottom} [/nodecliac] #`;

					// Edit .bashrc file to "include" nodecliac main script file.
					fs.writeFileSync(bashrcpath, `${contents}\n${bash_edit}`);
				}

				// Generate main and completion scripts.
				script("scripts/ac.sh", acscriptpath);
				script("scripts/main.sh", mscriptpath);
				script("scripts/ac.pl", acplscriptpath);
				script("scripts/config.pl", acplscriptconfigpath);
				// Make perl scripts executable.
				fs.chmodSync(acplscriptpath, "775");
				fs.chmodSync(acplscriptconfigpath, "775");

				// Give success message.
				log(chalk.green("Setup successful."));
			});
		});
	});
};
