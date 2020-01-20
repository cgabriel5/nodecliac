"use strict";

const path = require("path");
const chalk = require("chalk");
const flatry = require("flatry");
const log = require("fancy-log");
const mkdirp = require("make-dir");
const fe = require("file-exists");
const copydir = require("recursive-copy");
const de = require("directory-exists");
const through = require("through2");
const {
	fmt,
	exit,
	paths,
	read,
	write,
	strip_comments
} = require("../utils/toolbox.js");

module.exports = async args => {
	let { force, rcfilepath, commands } = args; // Get CLI args.

	// If command value is provided it must be a string list.
	if (commands && typeof commands !== "string") {
		exit([`${chalk.bold("--commands")} needs to be a string list.`]);
	}

	// Get needed paths.
	let { customdir, bashrcpath, mainscriptname, registrypath } = paths;
	let { acmapssource, resourcespath, resourcessrcs, setupfilepath } = paths;

	// If a custom .rcfile path was provided use that instead.
	if (rcfilepath) bashrcpath = rcfilepath;

	let err, res; // Declare empty variables to reuse for all await operations.
	let tstring = "";

	// If ~/.nodecliac exists force flag is needed to overwrite current install.
	[err, res] = await flatry(de(customdir));
	if (res && !force) {
		tstring = "? exists. Setup with ? to overwrite directory.";
		exit([fmt(tstring, chalk.bold(customdir), chalk.bold("--force"))]);
	}

	// If .rcfile does not exist, give message and end process.
	[err, res] = await flatry(fe(bashrcpath));
	if (!res) {
		exit([`${chalk.bold(bashrcpath)} file does not exist. Setup aborted.`]);
	}

	// Create needed paths: ~/.nodecliac/registry/ & ~/.nodecliac/src/
	[err, res] = await flatry(
		// [https://github.com/scopsy/await-to-js/issues/12#issuecomment-386147783]
		Promise.all([mkdirp(registrypath), mkdirp(acmapssource)])
	);

	// Get .rcfile script contents.
	[err, res] = await flatry(read(bashrcpath));

	// Check for nodecliac marker.
	if (!/^ncliac=~/m.test(res)) {
		// Edit .rcfile file to "include" nodecliac main script file.
		res = res.replace(/\n*$/g, ""); // Remove trailing newlines.
		tstring = // Template string.
			'?\n\nncliac=~/.nodecliac/src/main/?;if [ -f "$ncliac" ];then source "$ncliac";fi;';
		await flatry(write(bashrcpath, fmt(tstring, res, mainscriptname)));
	}

	// Create setup info file to reference on uninstall.
	let contents = JSON.stringify(
		{
			force: force || false,
			rcfilepath: bashrcpath,
			time: Date.now(),
			version: require("../../package.json").version
		},
		undefined,
		"\t"
	);
	[err, res] = await flatry(write(setupfilepath, contents));

	// Copy nodecliac command packages/files to nodecliac registry.
	[err, res] = await flatry(
		copydir(resourcessrcs, acmapssource, {
			// Copy options.
			overwrite: true,
			dot: false,
			debug: false,
			filter: function(filename) {
				return !/^\._/.test(filename); // Exclude hidden dirs/files.
			},
			transform: function(src /*dest, stats*/) {
				// Only modify Shell and Perl script files.
				if (!/\.(sh|pl|nim)$/.test(path.extname(src))) return null;

				// Remove comments from files and return.
				return through(function(chunk, enc, done) {
					done(null, strip_comments(chunk.toString()));
				});
			}
		})
	);
	// If copying fails give error.
	if (err) exit(["Failed to copy source files."]);

	// Copy nodecliac command packages/files to nodecliac registry.
	[err, res] = await flatry(
		copydir(resourcespath, registrypath, {
			overwrite: true,
			dot: true,
			debug: false,
			// filter: function(filename) { return !//.test(filename); },
			transform: function(src /*dest, stats*/) {
				// Only modify Shell and Perl script files.
				if (!/\.(sh|pl)$/.test(path.extname(src))) return null;

				// Remove comments from files and return.
				return through(function(chunk, enc, done) {
					done(null, strip_comments(chunk.toString()));
				});
			}
		})
	);
	// If copying fails give error.
	if (err) exit(["Failed to copy command files."]);

	// Give success message.
	log(chalk.green("Setup successful."));
};
