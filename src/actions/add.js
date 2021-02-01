"use strict";

const du = require("du");
const path = require("path");
const chalk = require("chalk");
const flatry = require("flatry");
const fe = require("file-exists");
const mkdirp = require("make-dir");
const check = require("./check.js");
const de = require("directory-exists");
const copydir = require("recursive-copy");
const toolbox = require("../utils/toolbox.js");
const { strip_trailing_slash } = toolbox;
const { fmt, exit, paths, lstats, download } = toolbox;
const { aexec, shrink, ispath_abs } = toolbox;
const hdir = require("os").homedir();

module.exports = async (args) => {
	let { registrypath } = paths;
	let { force, validate, "skip-val": skipval, path: p, repo } = args;

	if (p) if (!ispath_abs(p)) p = path.resolve(p);

	let sub = "";
	if (repo && !p) {
		let trunk = repo.indexOf("/trunk/");
		if (repo.includes("/trunk/")) {
			let parts = repo.split(/\/trunk\//);
			if (parts.length > 1) {
				repo = parts.shift();
				sub = parts.join(path.sep);
			}
		}
	}

	sub = strip_trailing_slash(sub);
	repo = strip_trailing_slash(repo);

	if (!repo) {
		let cwd = p || process.cwd();
		let dirname = path.basename(cwd);
		let pkgpath = `${registrypath}/${dirname}`;

		// If package exists error.
		let [err, res] = await flatry(de(pkgpath));
		if (err) process.exit();
		if (res) {
			let type = (await lstats(pkgpath)).is.symlink ? "Symlink " : "";
			let msg = `${type}?/ exists in registry. Remove it and try again.`;
			exit([fmt(msg, chalk.bold(dirname))]);
		}

		// Validate package base structure.
		if (!skipval && !(await check(dirname, cwd))) exit([]);

		// Skip size check when --force is provided.
		if (!force) {
			// Anything larger than 10MB must be force added.
			if ((await du(cwd)) / 1000 > 10000) {
				let msg = `?/ exceeds 10MB. Use --force to add package anyway.`;
				exit([fmt(msg, chalk.bold(dirname))]);
			}
		}

		// Copy folder to nodecliac registry.
		await mkdirp(pkgpath);
		let options = { overwrite: true, dot: true, debug: false };
		await copydir(cwd, pkgpath, options);
	}

	// Install via git/svn.
	else {
		let uri, cmd, err, res;
		let opts = { silent: true, async: true };
		let rname = repo.split(path.sep)[1];
		let output = `${hdir}/Downloads/${rname}-${Date.now()}`;

		// Reset rname if subdirectory is provided.
		if (sub) {
			let parts = sub.split(path.sep);
			rname = parts.pop();
		}

		// If package exists error.
		let pkgpath = `${registrypath}/${rname}`;
		[err, res] = await flatry(de(pkgpath));
		if (err) exit([]);
		if (res) {
			let type = (await lstats(pkgpath)).is.symlink ? "Symlink " : "";
			let msg = `${type}?/ exists in registry. Remove it and try again.`;
			exit([fmt(msg, chalk.bold(rname))]);
		}

		// Use git: [https://stackoverflow.com/a/60254704]
		if (!sub) {
			// Ensure repo exists by checking master branch.
			uri = `https://api.github.com/repos/${repo}/branches/master`;
			[err, res] = await flatry(download.str(uri));
			if (err || res.err) exit(["Provided URL does not exist."]);

			// Download repo with git.
			uri = `git@github.com:${repo}.git`;
			// [https://stackoverflow.com/a/42932348]
			cmd = `git clone ${uri} ${output}`;
			[err, res] = await flatry(aexec(cmd, opts));
		} else {
			// Use svn: [https://stackoverflow.com/a/18194523]

			// First check that svn is installed.
			cmd = "command -v svn";
			[err, res] = await flatry(aexec(cmd, opts));
			if (!res) exit(["`svn' is not installed."]);

			// Check that repo exists.
			uri = `https://github.com/${repo}/trunk/${sub}`;
			cmd = `svn ls ${uri}`;
			[err, res] = await flatry(aexec(cmd, opts));

			// prettier-ignore
			if (/svn: E\d{6}:/.test(err)) exit([`${chalk.red("Error:")} Provided repo URL does not exist.`]);

			// Use `svn ls` output here to validate package base structure.
			if (!skipval && !(await check(rname, res, true))) exit([]);

			// Use svn to download provided sub directory.
			cmd = `svn export ${uri} ${output}`;
			[err, res] = await flatry(aexec(cmd, opts));
		}

		// Validate package base structure.
		if (!skipval && !(await check(rname, output))) exit([]);

		// Move repo to registry.
		[err, res] = await flatry(de(registrypath));
		// prettier-ignore
		if (!res) exit([`nodecliac registry ${chalk.bold(registrypath)} doesn't exist.`]);
		// Delete existing registry package if it exists.
		[err, res] = await flatry(de(pkgpath));
		cmd = `rm -rf ${pkgpath}`;
		if (res) [err, res] = await flatry(aexec(cmd, opts));
		cmd = `mv ${output} ${pkgpath}`;
		[err, res] = await flatry(aexec(cmd, opts));
	}
};
