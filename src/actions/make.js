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
	let err, res; // Declare empty variables to reuse for all await operations.
	let tstring = "";

	// CLI args.
	let { source, print } = args; // `make` + `format` flags.
	let { trace, test } = args; // `make` flags.
	let { "strip-comments": igc, indent } = args; // `format` flags.

	let parser = require(`../parser/index.js`);

	// Formatting indentation values.
	let indent_char = "\t",
		indent_amount = 1;
	let formatting = args._[0] === "format";

	// If formatting check that indentation information was provided.
	if (formatting) {
		// If indentation flag was provided parse it and reset values.
		if (indent) {
			// Validate indentation flag.
			if (!/^(s|t):\d+$/.test(indent)) {
				exit([`Invalid indentation string.`]);
			}

			// If all good parse indentation string.
			let [char_type, indent_level] = indent.split(":", 2);
			// Reset values.
			indent_char = char_type;
			indent_amount = indent_level;
		}

		// Use literal chars (`s` => " ", `t` => "\t").
		indent_char = indent_char === "s" ? " " : "\t";
	}

	// Source must be provided.
	tstring = "Please provide a ? path.";
	if (!source) exit([fmt(tstring, chalk.bold("--source"))]);
	if (typeof source !== "string") {
		tstring = "? needs to be a string.";
		exit([fmt(tstring, chalk.bold("--source"))]);
	}

	// Breakdown path.
	let fi = info(source);
	let extension = fi.ext;
	let commandname = fi.name.replace(new RegExp(`\\.${extension}$`), "");
	let dirname = fi.dirname;

	// If path is relative make it absolute.
	if (!ispath_abs(source)) source = path.resolve(source);

	// If directory path supplied error.
	[err, res] = await flatry(de(source));
	if (err || res) exit(["Directory provided but .acmap file path needed."]);

	// Confirm acmap file path exists.
	[err, res] = await flatry(fe(source));
	if (err || !res) exit([fmt("Path ? does not exists.", chalk.bold(source))]);

	// Generate acmap.
	[err, res] = await flatry(read(source));
	let {
		placeholders,
		acdef: acmap,
		keywords,
		config,
		formatted,
		time
	} = parser(
		res,
		commandname,
		source,
		formatting ? [indent_char, indent_amount] : undefined,
		trace,
		igc,
		test
	);
	let savename = `${commandname}.acdef`;
	let saveconfigname = `.${commandname}.config.acdef`;

	// Only save files to disk when not testing.
	if (!test) {
		// Write formatted contents to disk.
		if (formatting) {
			[err, res] = await flatry(write(source, formatted.content));
		}
		// Write .acdef and .config.acdef files to disk.
		else {
			// Build file output paths.
			let commandpath = path.join(dirname, savename);
			let commandconfigpath = path.join(dirname, saveconfigname);
			let placeholderspaths = path.join(dirname, "placeholders");

			// Check if command.acdef file exists.
			[err, res] = await flatry(de(dirname));

			// Create needed parent directories.
			[err, res] = await flatry(mkdirp(dirname));

			// Save file to map location.
			await flatry(write(commandpath, acmap.content + keywords.content));
			await flatry(write(commandconfigpath, config.content));

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

				[err, res] = await flatry(Promise.all(promises)); // Run promises.
			}
		}
	}

	// Log acmap file contents if print flag provided.
	if (print) {
		// Print generated acdef/config file contents.
		if (!formatting) {
			if (acmap) {
				console.log(`\n[${chalk.bold(`${commandname}.acdef`)}]\n`);
				console.log(acmap.print + keywords.print);
				if (!config) console.log(); // Bottom padding.
			}
			if (config) {
				let msg = `\n[${chalk.bold(`.${commandname}.config.acdef`)}]\n`;
				console.log(msg);
				if (config.print) console.log(config.print + "\n");
			}
		}
		// If formatting print the output.
		else {
			let decor = "-".repeat(25);
			console.log(`\n${decor}${chalk.bold.blue(`Prettied`)}${decor}\n`);
			console.log(formatted.print);
			console.log(`${decor}${chalk.bold.blue(`Prettied`)}${decor}\n`);
		}

		// Time in seconds: [https://stackoverflow.com/a/41443682]
		// [https://stackoverflow.com/a/18031945]
		// [https://stackoverflow.com/a/1975103]
		// [https://blog.abelotech.com/posts/measure-execution-time-nodejs-javascript/]
		const duration = ((time[0] * 1e3 + time[1] / 1e6) / 1e3).toFixed(3);
		log(`Completed in ${chalk.green(duration + "s")}.`);
		console.log();
		// hrtime wrapper: [https://github.com/seriousManual/hirestime]
	}

	// For test (--test) purposes.
	if (test) {
		// Print generated acdef/config file contents.
		if (!formatting) {
			if (acmap) {
				console.log(acmap.print + keywords.print);
				if (!config) console.log(); // Bottom padding.
			}
			if (config) {
				if (acmap) console.log(); // Pad before logging config.
				if (config.print) console.log(config.print);
			}
		}
		// If formatting print the output.
		else console.log(formatted.print);
	}
};
