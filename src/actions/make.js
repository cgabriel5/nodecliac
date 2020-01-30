"use strict";

const path = require("path");
const chalk = require("chalk");
const flatry = require("flatry");
const log = require("fancy-log");
const fe = require("file-exists");
const mkdirp = require("make-dir");
const de = require("directory-exists");
const toolbox = require("../utils/toolbox.js");
const { fmt, exit, read, write, info, readdir, ispath_abs } = toolbox;

module.exports = async args => {
	// eslint-disable-next-line no-unused-vars
	let err, res;

	// CLI args.
	let { source, print } = args;
	let { trace, test } = args;
	let { "strip-comments": igc, indent } = args;
	let [action] = args._;
	let formatting = action === "format";

	let fmtinfo = ["\t", 1];
	// Parse and validate provided indentation.
	if (formatting && indent) {
		let r = /^(s|t):\d+$/;
		if (!r.test(indent)) exit([`Invalid indentation string.`]);
		fmtinfo = indent.split(":", 2);
		fmtinfo[0] = fmtinfo[0] === "s" ? " " : "\t";
	}

	// Source must be provided.
	let tstring = "Please provide a ? path.";
	if (!source) exit([fmt(tstring, chalk.bold("--source"))]);
	if (typeof source !== "string") {
		tstring = "? needs to be a string.";
		exit([fmt(tstring, chalk.bold("--source"))]);
	}

	// Breakdown path.
	let fi = info(source);
	let extension = fi.ext;
	let cmdname = fi.name.replace(new RegExp(`\\.${extension}$`), "");
	let dirname = fi.dirname;

	// If path is relative make it absolute.
	if (!ispath_abs(source)) source = path.resolve(source);

	// If directory path supplied error.
	[err, res] = await flatry(de(source));
	if (err || res) exit(["Directory provided but .acmap file path needed."]);

	// Confirm acmap file path exists.
	[err, res] = await flatry(fe(source));
	if (err || !res) exit([fmt("Path ? does not exists.", chalk.bold(source))]);

	[err, res] = await flatry(read(source));
	let parser = require(`../parser/index.js`);
	let pres = parser(action, res, cmdname, source, fmtinfo, trace, igc, test);
	let { acdef, config, keywords, placeholders, formatted, time } = pres;
	let savename = `${cmdname}.acdef`;
	let saveconfigname = `.${cmdname}.config.acdef`;

	// Only save files to disk when not testing.
	if (!test) {
		if (formatting) [err, res] = await flatry(write(source, formatted));
		else {
			let commandpath = path.join(dirname, savename);
			let commandconfigpath = path.join(dirname, saveconfigname);
			let placeholderspaths = path.join(dirname, "placeholders");

			[err, res] = await flatry(de(dirname));
			[err, res] = await flatry(mkdirp(dirname));

			await flatry(write(commandpath, acdef + keywords));
			await flatry(write(commandconfigpath, config));

			// -----------------------------------------------------PLACEHOLDERS

			// Create placeholder files when placeholders object is populated.
			if (Object.keys(placeholders).length) {
				// Create needed directories.
				[err, res] = await flatry(mkdirp(placeholderspaths));

				let promises = []; // Store promises.
				let f = Object.prototype.hasOwnProperty;

				// Loop over placeholders to create write promises.
				for (let key in placeholders) {
					if (f.call(placeholders, key)) {
						let p = `${placeholderspaths}/${key}`;
						promises.push(write(p, placeholders[key]));
					}
				}

				[err, res] = await flatry(Promise.all(promises));
			}
		}
	}

	// Log acdef file contents if print flag provided.
	if (print) {
		// Print generated acdef/config file contents.
		if (!formatting) {
			if (acdef) {
				console.log(`[${chalk.bold(`${cmdname}.acdef`)}]\n`);
				console.log(acdef + keywords);
				if (!config) console.log();
			}
			if (config) {
				let msg = `\n[${chalk.bold(`.${cmdname}.config.acdef`)}]\n`;
				console.log(msg);
				console.log(config + "\n");
			}
		} else console.log(formatted);

		// Time in seconds: [https://stackoverflow.com/a/41443682]
		// [https://stackoverflow.com/a/18031945]
		// [https://stackoverflow.com/a/1975103]
		// [https://blog.abelotech.com/posts/measure-execution-time-nodejs-javascript/]
		const duration = ((time[0] * 1e3 + time[1] / 1e6) / 1e3).toFixed(3);
		console.log(`Completed in ${chalk.green(duration + "s")}.`);
		// hrtime wrapper: [https://github.com/seriousManual/hirestime]
	}

	// For test (--test) purposes.
	if (test) {
		// Print generated acdef/config file contents.
		if (!formatting) {
			if (acdef) {
				console.log(acdef + keywords);
				if (!config) console.log();
			}
			if (config) {
				if (acdef) console.log();
				console.log(config);
			}
		} else console.log(formatted);
	}
};
