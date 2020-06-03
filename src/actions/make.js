"use strict";

const path = require("path");
const chalk = require("chalk");
const flatry = require("flatry");
const fe = require("file-exists");
const mkdirp = require("make-dir");
const de = require("directory-exists");
const toolbox = require("../utils/toolbox.js");
const { fmt, exit, read, write, info, ispath_abs, hasProp } = toolbox;

module.exports = async (args) => {
	// eslint-disable-next-line no-unused-vars
	let err, res;

	let { source, print } = args;
	let { trace, test } = args;
	let { "strip-comments": igc, indent } = args;
	let [action] = args._;
	let formatting = action === "format";

	let fmtinfo = ["\t", 1];
	// Parse/validate indentation.
	if (formatting && indent) {
		let r = /^(s|t):\d+$/;
		if (!r.test(indent)) exit([`Invalid indentation string.`]);
		fmtinfo = indent.split(":", 2);
		fmtinfo[0] = fmtinfo[0] === "s" ? " " : "\t";
	}

	// Source must be provided.
	let tstring = "Please provide a ? path.";
	if (!source) exit([fmt(tstring, chalk.bold("--source"))]);

	// Breakdown path.
	let fi = info(source);
	let extension = fi.ext;
	let cmdname = fi.name.replace(new RegExp(`\\.${extension}$`), "");
	let dirname = fi.dirname;

	// Make path absolute.
	if (!ispath_abs(source)) source = path.resolve(source);

	[err, res] = await flatry(de(source));
	if (err || res) exit(["Directory provided but .acmap file path needed."]);
	[err, res] = await flatry(fe(source));
	if (err || !res) exit([fmt("Path ? doesn't exist.", chalk.bold(source))]);

	[err, res] = await flatry(read(source));
	let parser = require(`../parser/index.js`);
	let pres = parser(action, res, cmdname, source, fmtinfo, trace, igc, test);
	let { acdef, config, keywords, filedirs, placeholders, formatted } = pres;
	let savename = `${cmdname}.acdef`;
	let saveconfigname = `.${cmdname}.config.acdef`;

	// Only save files to disk when not testing.
	if (!test) {
		if (formatting) [err, res] = await flatry(write(source, formatted));
		else {
			let commandpath = path.join(dirname, savename);
			let commandconfigpath = path.join(dirname, saveconfigname);
			let placeholderspaths = path.join(dirname, "placeholders");

			await flatry(mkdirp(dirname));
			await flatry(write(commandpath, acdef + keywords + filedirs));
			await flatry(write(commandconfigpath, config));

			// Create placeholder files if object is populated.
			if (Object.keys(placeholders).length) {
				let promises = [];
				await flatry(mkdirp(placeholderspaths));

				// Create promises.
				for (let key in placeholders) {
					if (hasProp(placeholders, key)) {
						let p = `${placeholderspaths}/${key}`;
						promises.push(write(p, placeholders[key]));
					}
				}

				await flatry(Promise.all(promises));
			}
		}
	}

	if (print) {
		if (!formatting) {
			if (acdef) {
				console.log(`[${chalk.bold(`${cmdname}.acdef`)}]\n`);
				console.log(acdef + keywords + filedirs);
				if (!config) console.log();
			}
			if (config) {
				let msg = `\n[${chalk.bold(`.${cmdname}.config.acdef`)}]\n`;
				console.log(msg);
				console.log(config + "\n");
			}
		} else console.log(formatted);

		// // Time in seconds: [https://stackoverflow.com/a/41443682]
		// // [https://stackoverflow.com/a/18031945]
		// // [https://stackoverflow.com/a/1975103]
		// // [https://blog.abelotech.com/posts/measure-execution-time-nodejs-javascript/]
		// const duration = ((time[0] * 1e3 + time[1] / 1e6) / 1e3).toFixed(3);
		// console.log(`Completed in ${chalk.green(duration + "s")}.`);
		// // hrtime wrapper: [https://github.com/seriousManual/hirestime]
	}

	// Test (--test) purposes.
	if (test) {
		if (!formatting) {
			if (acdef) {
				console.log(acdef + keywords + filedirs);
				if (!config) console.log();
			}
			if (config) {
				if (acdef) console.log();
				console.log(config);
			}
		} else console.log(formatted);
	}
};
