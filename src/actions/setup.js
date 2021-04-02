"use strict";

const path = require("path");
const chalk = require("chalk");
const shell = require("shelljs");
const fe = require("file-exists");
const mkdirp = require("make-dir");
const through = require("through2");
const de = require("directory-exists");
const copydir = require("recursive-copy");
const toolbox = require("../utils/toolbox.js");
const prompt = require("prompt-sync")({ sigint: true });
const { fmt, exit, paths, read, write, strip_comments, chmod } = toolbox;

module.exports = async (args) => {
	let { force, update, rcfile, packages, yes, jsInstall } = args;
	let err, res;
	let tstring = "";

	let { ncliacdir, bashrcpath, mainscriptname, registrypath } = paths;
	let { acmapssource, resourcespath, resourcessrcs, setupfilepath } = paths;
	let { testsrcpath } = paths;
	if (rcfile) bashrcpath = rcfile; // Use provided path.

	if ((await de(ncliacdir)) && !(force || update)) {
		tstring = "? exists. Setup with ? to overwrite directory.";
		exit([fmt(tstring, chalk.bold(ncliacdir), chalk.bold("--force"))]);
	}

	// Create default rcfile if needed.
	if (!(await fe(bashrcpath))) await write(bashrcpath, "", 0o644);

	// [https://github.com/scopsy/await-to-js/issues/12#issuecomment-386147783]
	await Promise.all([mkdirp(registrypath), mkdirp(acmapssource)]);

	res = await read(bashrcpath);
	if (!/^ncliac=~/m.test(res)) {
		let answer = "";
		let modrcfile = false;
		// prettier-ignore
		if (!yes) {
			// Ask user whether to add nodecliac to rcfile.
			let chomedir = bashrcpath.replace(new RegExp("^" + paths.homedir), "~");
			console.log(`${chalk.bold.magenta("Prompt")}: For nodecliac to work it needs to be added to your rcfile.`);
			console.log(`    ... The following line will be appended to ${chalk.bold(chomedir)}:`);
			console.log(`    ... ${chalk.italic('ncliac=~/.nodecliac/src/main/init.sh; [ -f "$ncliac" ] && . "$ncliac";')}`);
			console.log("    ... (if skipping, manually add it after install to use nodecliac)");
			// [https://www.codecademy.com/articles/getting-user-input-in-node-js]
			answer = prompt(`${chalk.bold.magenta("Answer")}: [Press enter for default: Yes] ${chalk.bold("Add nodecliac to rcfile?")} [Y/n] `);
			if (/^[Yy]/.test(answer)) modrcfile = true;
			// Remove question/answer lines.
			shell.exec("tput cuu 1 && tput el;".repeat(5));
		}
		if (!answer || yes) modrcfile = true;

		if (modrcfile) {
			res = res.replace(/\n*$/g, ""); // Remove trailing newlines.
			tstring =
				'?\nncliac=~/.nodecliac/src/main/?; [ -f "$ncliac" ] && . "$ncliac";';
			await write(bashrcpath, fmt(tstring, res, mainscriptname));
		}
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

	/**
	 * Ensure script files are executable.
	 *
	 * @param  {object} op - The files CopyOperation object.
	 * @return {undefined} - Nothing is returned.
	 */
	let cmode = async (operation) => {
		let p = operation.dest;
		if (/\.(sh|pl|nim)$/.test(p)) await chmod(p, 0o775);
	};

	// If flag isn't provided don't install packages except nodecliac.
	if (!packages) {
		resourcespath = path.join(resourcespath, "nodecliac");
		registrypath = path.join(registrypath, "nodecliac");
	}
	await Promise.all([
		copydir(resourcessrcs, acmapssource, {
			overwrite: true,
			dot: false,
			filter: (filename) => files.has(filename),
			transform: (src /*dest, stats*/) => {
				if (!/\.(sh|pl|nim)$/.test(path.extname(src))) return null;
				return transform();
			}
		}).on(copydir.events.COPY_FILE_COMPLETE, cmode),
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
		}).on(copydir.events.COPY_FILE_COMPLETE, cmode),
		// Copy nodecliac command packages/files to nodecliac registry.
		copydir(resourcespath, registrypath, {
			overwrite: true,
			dot: true,
			// Ignore .git folder and root files. Only copy completion packages.
			filter: (f) => !(f.startsWith(".git") || !-~f.indexOf("/")),
			transform: (src /*dest, stats*/) => {
				if (!/\.(sh|pl)$/.test(path.extname(src))) return null;
				return transform();
			}
		}).on(copydir.events.COPY_FILE_COMPLETE, cmode)
	]);

	if (!jsInstall) console.log(chalk.green("Setup successful."));
};
