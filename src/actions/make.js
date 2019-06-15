"use strict";

// Needed modules.
const fs = require("fs");
const path = require("path");
const chalk = require("chalk");
const flatry = require("flatry");
const log = require("fancy-log");
const fe = require("file-exists");
const {
	exit,
	paths,
	remove,
	read,
	write,
	info
} = require("../utils/toolbox.js");

module.exports = async args => {
	// Get needed paths.
	let { commandspaths } = paths;
	// Declare empty variables to reuse for all await operations.
	let err, res;

	// Get CLI args.
	let {
		source,
		print,
		add,
		save,
		indent,
		"strip-comments": igc,
		highlight,
		trace,
		nowarn
	} = args;
	let parser = require("../parser/main.js");
	// Formatting indentation values.
	let indent_char = "\t",
		indent_amount = 1;
	let formatting = args._[0] === "format";

	// If formatting check that indentation information was provided.
	if (formatting) {
		// If indent flag is not provided exit and error.
		if (!indent) {
			exit([
				`Please provide indentation information via ${chalk.bold(
					"--indent"
				)} flag.`
			]);
		}

		// Validate indentation flag.
		if (typeof indent !== "string") {
			exit([`${chalk.bold("--indent")}'s value must be a string.`]);
		}

		// Validate indentation flag.
		if (!/^(s|t):\d$/.test(indent)) {
			exit([`Invalid indentation value.`]);
		}

		// Else if all good, parse indentation information.
		let parts = indent.split(":", 2);
		// Get values.
		indent_char = parts[0];
		indent_amount = parts[1];
		// Set default values.
		indent_char = indent_char === "s" ? " " : "\t";
		indent_amount;
		// Cast amount to number.
		indent_amount;

		// // Set print flag to bypass checks.
		// args.print = true;
		// print = true;
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

	// Turn source path to absolute path.
	source = path.join(process.cwd(), source);

	// Also requires one of the following flags to do anything.
	if (!(save || add || print || indent)) {
		exit([
			`Must also provide one of the following flags: ${chalk.bold(
				"--save"
			)}, ${chalk.bold("--add")}, ${chalk.bold("--print")}.`
		]);
	}

	// Check that the source path exists.
	[err, res] = await flatry(fe(source));
	// If path does not exist, give message and end process.
	if (!res) {
		exit([`${chalk.bold(source)} does not exist.`]);
	}

	// Generate acmap.
	[err, res] = await flatry(read(source));
	let { acdef: acmap, keywords, config, formatted, time } = parser(
		res,
		commandname,
		source,
		formatting ? [indent_char, indent_amount] : undefined,
		highlight,
		trace,
		nowarn,
		igc
	);
	let savename = `${commandname}.acdef`;
	let saveconfigname = `.${commandname}.config.acdef`;

	// Save formatted acmap file to source location when flag is provided.
	if (save && formatting) {
		[err, res] = await flatry(write(source, formatted.content));
	}
	// Save definitions file to source location when flag is provided.
	else if (save) {
		let data = acmap.content + keywords.content;
		await flatry(write(path.join(fi.dirname, savename), data));
		await flatry(path.join(fi.dirname, saveconfigname), config.data);
	}

	// Add to maps location if add flag provided.
	if (add) {
		// Build file output paths.
		let commanddir = path.join(commandspaths, commandname);
		let commandpath = path.join(commanddir, savename);
		let commandconfigpath = path.join(commanddir, saveconfigname);

		// Check if command.acdef file exists.
		[err, res] = await flatry(fe(commandpath));
		if (!res || args.force) {
			// Save file to map location.
			await flatry(write(commandpath, acmap.content + keywords.content));
			await flatry(write(commandconfigpath, config.content));

			log(`${chalk.bold(commandname)} acmap added.`);
		} else {
			log(
				`acmap ${chalk.bold(commandname)} exists (use ${chalk.bold(
					"--force"
				)} to overwrite current acmap).`
			);
		}
	}

	// Log acmap file contents if print flag provided.
	if (print) {
		// Print generated acdef/config file contents.
		if (!formatting) {
			if (acmap) {
				console.log(`[${chalk.bold(`${commandname}.acdef`)}]\n`);
				console.log(acmap.print + keywords.print);
				if (!config) {
					console.log(); // Bottom padding.
				}
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
};