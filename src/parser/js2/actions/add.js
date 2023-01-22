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
	let { registrypath, ncliacdir } = paths;
	let {
		"allow-size": allowsize,
		"allow-structure": allowstructure,
		"allow-overwrite": allowoverwrite,
		force,
		path: p,
		repo = "" } = args;
	let positional = args._;

	// Handle '$ nodecliac add nodecliac'.
	if (positional.length > 1) {
		let pkg_name = positional[1];
		let packageslist = path.join(ncliacdir, "packages.json");
		let [err, res] = await flatry(fe(packageslist));
		let localpkglist = chalk.bold(packageslist);
		if (res) {
			let pkgd;
			let packages = require(packageslist);
			for (let i = 0, l = packages.length; i < l; i++) {
				let pkg = packages[i];
				if (pkg.name === pkg_name) {
					pkgd = pkg;
					repo = pkg.repo;
					break;
				}
			}
			// Error if package not in list.
			if (!pkgd) {
				exit([`${chalk.red("Error:")} Package ${chalk.bold(pkg_name)} not found in local ${localpkglist}.`]);
			}
		} else {
			// [TODO] Handle when packages.json doesn't exist.
			exit([`${chalk.red("Error:")} Local ${localpkglist} not found.`]);
		}
	}

	if (p) if (!ispath_abs(p)) p = path.resolve(p);

	let sub = "";
	let url = false;
	if (repo && !p) {
		if (repo.startsWith("https://") || repo.startsWith("git@")) {
			if (!repo.endsWith(".git")) {
				exit([`${chalk.red("Error:")} Repo URL is invalid.`]);
			}
			url = true;
		} else if (-~repo.indexOf("/trunk/")) {
			let parts = repo.split(/\/trunk\//);
			if (parts.length > 1) {
				repo = parts.shift();
				sub = parts.join(path.sep);
			}
		}
	}

	// Extract possibly provided branch name.
	let ht_index = repo.indexOf("#");
	let branch = "master";
	if (-~ht_index) {
		branch = repo.substr(ht_index + 1);
		repo = repo.substr(0, ht_index);
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
		if (res && !(force || allowoverwrite)) {
			let type = (await lstats(pkgpath)).is.symlink ? "Symlink " : "";
			let msg = `${type}?/ exists in registry. Remove it and try again or install with ${chalk.bold("--allow-overwrite")}.`;
			exit([fmt(msg, chalk.bold(dirname))]);
		}

		// Validate package base structure.
		if (!(force || allowstructure) && !(await check(dirname, cwd))) exit([]);

		// Skip size check when --allow-size is provided.
		if (!(force || allowsize)) {
			// Anything larger than 10MB must be force added.
			if ((await du(cwd)) / 1000 > 10000) {
				let msg = `?/ exceeds 10MB. Use ${chalk.bold("--allow-size")} to add package anyway.`;
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
		if (url) rname = repo.match(/([^/]+)\.git$/)[1];
		if (sub) rname = sub.split(path.sep).pop();
		let output = `${hdir}/Downloads/${rname}-${Date.now()}`;

		// If package exists error.
		let pkgpath = `${registrypath}/${rname}`;
		[err, res] = await flatry(de(pkgpath));
		if (err) exit([]);
		if (res && !(force || allowoverwrite)) {
			let type = (await lstats(pkgpath)).is.symlink ? "Symlink " : "";
			let msg = `${type}?/ exists in registry. Remove it and try again or install with ${chalk.bold("--allow-overwrite")}.`;
			exit([fmt(msg, chalk.bold(rname))]);
		}

		if (url) {
			// [https://stackoverflow.com/a/42932348]
			cmd = `git clone ${repo} ${output}`;
			[err, res] = await flatry(aexec(cmd, opts));

		// Use git: [https://stackoverflow.com/a/60254704]
		} else if (!sub) {
			// Ensure repo exists.
			uri = `https://api.github.com/repos/${repo}/branches/${branch}`;
			[err, res] = await flatry(download.str(uri));
			if (err || res.err) exit(["URL does not exist."]);

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
			// prettier-ignore
			if (branch != "master") uri = `https://github.com/${repo}/branches/${branch}/${sub}`;
			cmd = `svn ls ${uri}`;
			[err, res] = await flatry(aexec(cmd, opts));

			// prettier-ignore
			if (/svn: E\d{6}:/.test(err)) exit([`${chalk.red("Error:")} Repo URL does not exist.`]);

			// Use `svn ls` output here to validate package base structure.
			if (!(force || allowstructure) && !(await check(rname, res, true))) exit([]);

			// Use svn to download provided sub directory.
			cmd = `svn export ${uri} ${output}`;
			[err, res] = await flatry(aexec(cmd, opts));
		}

		// Validate package base structure.
		if (!(force || allowstructure) && !(await check(rname, output))) exit([]);

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
