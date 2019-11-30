"use strict";

// Needed modules.
const path = require("path");
const chalk = require("chalk");
const flatry = require("flatry");
const log = require("fancy-log");
const fe = require("file-exists");
const mkdirp = require("make-dir");
const de = require("directory-exists");
const {
	exit,
	paths,
	read,
	write,
	info,
	readdir,
	ispath_abs
} = require("../utils/toolbox.js");

module.exports = async args => {
	// Get needed paths.
	let { registrypaths } = paths;
	// Declare empty variables to reuse for all await operations.
	// eslint-disable-next-line no-unused-vars
	let err, res;

	// Get CLI args.
	let {
		// `make` + `format` flags:
		source,
		print,
		save,
		// `make` action flags:
		force,
		trace,
		test,
		add,
		// `format` action flags:
		"strip-comments": igc,
		highlight,
		indent,
		// Other flags:
		nowarn,
		engine
	} = args;

	// Get list of available engines.
	[err, res] = await flatry(
		readdir(path.join(path.parse(__dirname).dir, "/parser"))
	);
	// Filter content to only return version directories.
	let engines = res
		.filter(item => /^v\d+$/.test(item))
		.map(item => +item.replace("v", ""));

	// Default to latest engine if engine version isn't specified.
	engine = engine || engines[engines.length - 1];

	// If engine does not exist error.
	if (!engines.includes(engine)) {
		exit([`Engine: ${chalk.bold(engine)} does not exist.`]);
	}

	// Require parser engine script.
	let parser = require(`../parser/v${engine}/index.js`);

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

		// Reset char to its literal character (`s` => " ", `t` => "\t").
		indent_char = indent_char === "s" ? " " : "\t";
	}

	// Source must be provided.
	if (!source) {
		exit([`Please provide a ${chalk.bold("--source")} path.`]);
	}
	if (typeof source !== "string") {
		exit([`${chalk.bold("--source")} needs to be a string.`]);
	}
	// Check path for file name and extension.
	let fi = info(source);
	if (!/^[a-z][-_+a-z0-9]{2,}\.acmap$/i.test(fi.name)) {
		exit([
			`File name must follow format: ${chalk.bold.blue(
				"<cli-command-name>.acmap"
			)}.`,
			`Examples: ${chalk.bold("prettier.acmap")}, ${chalk.bold(
				"prettier-cli-watcher.acmap"
			)}.`
		]);
	}
	// Extract the command name.
	let commandname = fi.name.match(/^[-_:+a-z0-9]+/g)[0].replace(/_/g, "-");

	// If path is relative make it absolute.
	if (!ispath_abs(source)) source = path.resolve(source);

	// If `--save` flag is provided but path is not given use dir location.
	if (save && save === true) save = fi.dirname;

	// Check that the source path exists.
	[err, res] = await flatry(fe(source));
	// If path does not exist, give message and end process.
	if (!res) {
		exit([
			`${chalk.bold(source)} (${chalk.blue("--source")}) doesn't exist.`
		]);
	}

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
		highlight,
		trace,
		nowarn,
		igc,
		test
	);
	let savename = `${commandname}.acdef`;
	let saveconfigname = `.${commandname}.config.acdef`;

	// When formatting...
	if (formatting) {
		// Save formatted acmap file to source location when flag is provided.
		if (save) [err, res] = await flatry(write(source, formatted.content));
	}
	// When generating nodecliac completion-package.
	else {
		let __paths = []; // Locations where to save completion-package.
		if (add) __paths.push(registrypaths);
		// Note: If an save path is not provided use source location.
		if (save) __paths.push(save);

		// Save nodecliac completion-package at locations in array.
		for (let i = 0, l = __paths.length; i < l; i++) {
			// Build file output paths.
			let commanddir = path.join(__paths[i], commandname);
			let commandpath = path.join(commanddir, savename);
			let commandconfigpath = path.join(commanddir, saveconfigname);
			let placeholderspaths = path.join(commanddir, "placeholders");

			// Check if command.acdef file exists.
			[err, res] = await flatry(de(commanddir));
			// [err, res] = await flatry(fe(commandpath));

			// To save completion-package to disk the main folder cannot
			// exist at the provided/current directory location. This will
			// prevent the overwriting the current package. Or if the
			// `--force` flag is provided.
			if (res && !args.force) continue;

			// Create needed parent directories.
			[err, res] = await flatry(mkdirp(commanddir));

			// Save file to map location.
			await flatry(write(commandpath, acmap.content + keywords.content));
			await flatry(write(commandconfigpath, config.content));

			// -----------------------------------------------------PLACEHOLDERS

			// Create placeholder files when placeholders object is populated.
			if (Object.keys(placeholders).length) {
				// Create needed directories.
				[err, res] = await flatry(mkdirp(placeholderspaths));
				if (!res) continue;

				let promises = []; // Store promises.
				let f = Object.prototype.hasOwnProperty;

				// Loop over placeholders to create write promises.
				for (let key in placeholders) {
					if (f.call(placeholders, key)) {
						promises.push(
							write(
								`${placeholderspaths}/${key}`,
								placeholders[key]
							)
						);
					}
				}

				// Run promises.
				[err, res] = await flatry(Promise.all(promises));
			}
		}
	}

	// Log acmap file contents if print flag provided.
	if (print) {
		// Print generated acdef/config file contents.
		if (!formatting) {
			if (acmap) {
				console.log(`[${chalk.bold(`${commandname}.acdef`)}]\n`);
				console.log(acmap.print + keywords.print);
				if (!config) console.log(); // Bottom padding.
			}
			if (config) {
				console.log(
					`\n[${chalk.bold(`.${commandname}.config.acdef`)}]\n`
				);
				console.log(config.print);
				console.log(); // Bottom padding.
			}
		}
		// If formatting print the output.
		else {
			console.log(
				`${"-".repeat(25)}${chalk.bold.blue(`Prettied`)}${"-".repeat(
					25
				)}\n`
			);
			console.log(formatted.print);
			console.log(
				`\n${"-".repeat(25)}${chalk.bold.blue(`Prettied`)}${"-".repeat(
					25
				)}\n`
			);
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
				if (acmap) console.log(); // Pad before config.
				console.log(config.print);
			}
		}
		// If formatting print the output.
		else {
			console.log(formatted.print);
		}
	}
};
