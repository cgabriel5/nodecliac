"use strict";

const os = require("os");
const path = require("path");

// let pwd = process.env.PWD; // [https://stackoverflow.com/a/39740187]
// [https://stackoverflow.com/a/29496638]
let cwd = path.dirname(path.dirname(__dirname));
let homedir = os.homedir();
let projectname = "nodecliac";
let ncliacdir = path.join(homedir, `.${projectname}`);
let bashrcpath = path.join(homedir, ".bashrc");
let mainscriptname = "init.sh";
let registrypath = path.join(homedir, `.${projectname}`, "registry");
let acmapssource = path.join(homedir, `.${projectname}`, "src");
let setupfilepath = path.join(ncliacdir, `.setup.db.json`);
let resourcespath = path.join(cwd, "resources", "packages");
let resourcessrcs = path.join(cwd, "src", "scripts");
let testsrcpath = path.join(cwd, "tests", "scripts");
let cachepath = path.join(homedir, `.${projectname}`, ".cache");
let cachelevel = path.join(homedir, `.${projectname}`, ".cache-level");

module.exports = {
	paths: {
		cwd,
		homedir,
		ncliacdir,
		bashrcpath,
		mainscriptname,
		registrypath,
		acmapssource,
		setupfilepath,
		resourcespath,
		resourcessrcs,
		testsrcpath,
		cachepath,
		cachelevel
	}
};
