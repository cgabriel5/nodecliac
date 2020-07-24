"use strict";

const path = require("path");
const chalk = require("chalk");
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

	if ((await de(ncliacdir)) && !force) {
		tstring = "? exists. Setup with ? to overwrite directory.";
		exit([fmt(tstring, chalk.bold(ncliacdir), chalk.bold("--force"))]);
	}

	if (!(await fe(bashrcpath))) {
		exit([`${chalk.bold(bashrcpath)} file doesn't exist.`]);
	}

	// [https://github.com/scopsy/await-to-js/issues/12#issuecomment-386147783]
	await Promise.all([mkdirp(registrypath), mkdirp(acmapssource)]);

	res = await read(bashrcpath);
	if (!/^ncliac=~/m.test(res)) {
		res = res.replace(/\n*$/g, ""); // Remove trailing newlines.
		tstring =
			'?\nncliac=~/.nodecliac/src/main/?; [ -f "$ncliac" ] && . "$ncliac";';
		await write(bashrcpath, fmt(tstring, res, mainscriptname));
	}

	// Create setup info file to reference on uninstall.
	let data = {};
	data.force = force || false;
	data.rcfile = bashrcpath;
	data.time = Date.now();
	data.version = require("../../package.json").version;
	let contents = JSON.stringify(data, undefined, "\t");
	await write(setupfilepath, contents);

	let files = new Set([
		"ac/ac.pl",
		"ac/ac_debug.pl",
		"ac/utils",
		"ac/utils/LCP.pm",
		"bin/ac.linux",
		"bin/ac_debug.linux",
		"main/config.pl",
		"main/init.sh"
	]);
	if (process.platform === "darwin") {
		let list = ["ac", "ac_debug"];
		list.forEach((name) => files.delete(`bin/${name}.linux`));
		list.forEach((name) => files.add(`bin/${name}.macosx`));
	}
	let mainpath = path.join(acmapssource, "main");

	// Remove comments from '#' comments from files.
	let transform = function (chunk, enc, done) {
		return through((chunk, enc, done) => {
			done(null, strip_comments(chunk.toString()));
		});
	};

	await Promise.all([
		// Copy completion packages.
		copydir(resourcessrcs, acmapssource, {
			overwrite: true,
			dot: false,
			filter: (filename) => files.has(filename),
			transform: (src /*dest, stats*/) => {
				if (!/\.(sh|pl|nim)$/.test(path.extname(src))) return null;
				return transform();
			}
		}),
		// Copy nodecliac.sh test file.
		copydir(testsrcpath, mainpath, {
			overwrite: true,
			dot: false,
			filter: ["nodecliac.sh"],
			rename: (/*p*/) => "test.sh",
			transform: (src /*dest, stats*/) => {
				if (!/\.(sh)$/.test(path.extname(src))) return null;
				return transform(src);
			}
		}),
		// Copy nodecliac command packages/files to nodecliac registry.
		copydir(resourcespath, registrypath, {
			overwrite: true,
			dot: true,
			transform: (src /*dest, stats*/) => {
				if (!/\.(sh|pl)$/.test(path.extname(src))) return null;
				return transform();
			}
		})
	]);

	log(chalk.green("Setup successful."));
};
