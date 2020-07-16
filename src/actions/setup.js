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
const toolbox = require("../utils/toolbox.js");
const { fmt, exit, paths, read, write, strip_comments } = toolbox;

module.exports = async (args) => {
	let { force, rcfile, commands } = args;
	let err, res;
	let tstring = "";

	if (commands && typeof commands !== "string") {
		exit([`${chalk.bold("--commands")} needs to be a string list.`]);
	}

	let { ncliacdir, bashrcpath, mainscriptname, registrypath } = paths;
	let { acmapssource, resourcespath, resourcessrcs, setupfilepath } = paths;
	let { testsrcpath } = paths;
	if (rcfile) bashrcpath = rcfile; // Use provided path.

	[err, res] = await flatry(de(ncliacdir));
	if (res && !force) {
		tstring = "? exists. Setup with ? to overwrite directory.";
		exit([fmt(tstring, chalk.bold(ncliacdir), chalk.bold("--force"))]);
	}

	[err, res] = await flatry(fe(bashrcpath));
	if (!res) exit([`${chalk.bold(bashrcpath)} file doesn't exist.`]);

	// [https://github.com/scopsy/await-to-js/issues/12#issuecomment-386147783]
	await flatry(Promise.all([mkdirp(registrypath), mkdirp(acmapssource)]));

	[err, res] = await flatry(read(bashrcpath));
	if (!/^ncliac=~/m.test(res)) {
		res = res.replace(/\n*$/g, ""); // Remove trailing newlines.
		tstring =
			'?\nncliac=~/.nodecliac/src/main/?; [ -f "$ncliac" ] && . "$ncliac";';
		await flatry(write(bashrcpath, fmt(tstring, res, mainscriptname)));
	}

	// Create setup info file to reference on uninstall.
	let data = {};
	data.force = force || false;
	data.rcfile = bashrcpath;
	data.time = Date.now();
	data.version = require("../../package.json").version;
	let contents = JSON.stringify(data, undefined, "\t");
	[err, res] = await flatry(write(setupfilepath, contents));

	// Copy directory module options.
	let opts = {};
	opts.overwrite = true;
	opts.dot = false;
	opts.debug = false;
	let files = new Set([
		"ac/ac.pl",
		"ac/utils",
		"ac/utils/LCP.pm",
		"bin/ac.linux",
		"main/config.pl",
		"main/init.sh"
	]);
	if (process.platform === "darwin") {
		files.delete("bin/ac.linux");
		files.add("bin/ac.macosx");
	}
	opts.filter = (filename) => files.has(filename);
	opts.transform = (src /*dest, stats*/) => {
		if (!/\.(sh|pl|nim)$/.test(path.extname(src))) return null;
		// Remove comments from files and return.
		return through((chunk, enc, done) => {
			done(null, strip_comments(chunk.toString()));
		});
	};

	// Copy nodecliac command packages/files to nodecliac registry.
	[err, res] = await flatry(copydir(resourcessrcs, acmapssource, opts));
	if (err) exit(["Failed to copy source files."]);

	// Copy test file over.
	files = new Set(["nodecliac.sh"]);
	opts.filter = (filename) => files.has(filename);
	opts.rename = (p) => "test.sh";
	let mainpath = path.join(acmapssource, "main");
	[err, res] = await flatry(copydir(testsrcpath, mainpath, opts));
	if (err) exit(["Failed to copy source files."]);

	opts.dot = true;
	delete opts.filter;
	opts.transform = (src /*dest, stats*/) => {
		if (!/\.(sh|pl)$/.test(path.extname(src))) return null;
		// Remove comments from files and return.
		return through((chunk, enc, done) => {
			done(null, strip_comments(chunk.toString()));
		});
	};

	// Copy nodecliac command packages/files to nodecliac registry.
	[err, res] = await flatry(copydir(resourcespath, registrypath, opts));
	if (err) exit(["Failed to copy command files."]);

	log(chalk.green("Setup successful."));
};
