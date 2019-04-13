"use strict";

// Needed modules.
const chalk = require("chalk");
const minimist = require("minimist");
// Get CLI parameters.
const args = minimist(process.argv.slice(2));
// Get RegExp patterns.
const { r_number } = require("./h.patterns.js");

module.exports = (value, ...scopes) => {
	// Get globals
	let stripansi = global.$app.get("stripansi");

	// Context:color lookup table.
	let c = {
		// Magenta → settings, flags
		setting: "magenta",
		flag: "magenta",
		// Brown → strings, values*
		string: "yellow",
		value: "yellow",
		// Blue → false/true, shortcuts
		boolean: "blue",
		shortcut: "blue",
		// Cyan → escape characters
		escape: "cyan",
		// Green → numbers
		number: "green",
		// Dim (gray) → comments
		comment: "dim",
		// Command-flag '$'.
		cmdflag: "magenta",
		// Default text.
		def: "reset",
		// Font styles.
		i: "italic",
		dim: "dim"
	};

	// Store whether value is a single value or an array of values.
	let is_singleton = typeof value === "string";
	let values = is_singleton ? [value] : value;

	// Check whether a loop stop modifier was provided.
	let stopmod;
	if (scopes.length >= 2 && /^:\/\d$/.test(scopes[scopes.length - 1])) {
		stopmod = scopes.pop();
	}

	// Add syntax highlighting.
	if (args.highlight) {
		// Loop over each scope/context.
		for (let i = 0, l = scopes.length; i < l; i++) {
			// Cache current loop item.
			let scope = scopes[i];

			// Loop over each value and apply scope highlighting logic.
			for (let i = 0, l = values.length; i < l; i++) {
				// Cache current loop item.
				let value = values[i];

				// Run loop continue check if stop mod flag is set.
				if (stopmod) {
					if (stopmod === ":/1") {
						// Only highlight command-flags.
						if (!value.startsWith("$(")) {
							continue;
						}
					} else if (stopmod === ":/2") {
						// Skip anything but option list values.
						if (!value || value.startsWith("\\")) {
							continue;
						}
					} else if (stopmod === ":/3") {
						// Skip anything but option list values.
						// [https://stackoverflow.com/a/13801337]
						// [https://stackoverflow.com/a/1697749]
						if (
							i === 0 &&
							(!value || value === "(" || /^\u001b/.test(value))
						) {
							continue;
						}
					}
				}

				// Apply scope highlighting logic to value.
				switch (scope) {
					case "value":
						// Keyword: false|true.
						if (/^(true|false)$/.test(value)) {
							value = chalk[c.boolean](value);
						}
						// Number:
						else if (r_number.test(value)) {
							value = chalk[c.number](value);
						}
						// String or anything else.
						else {
							// Check if value is a string.
							let is_str = /^["']/.test(value);

							// Highlight escaped sequences.
							value = value.replace(
								/(\\.)/g,
								`${chalk[c.escape]("$1")}`
							);

							// Check whether value is a string.
							if (is_str) {
								// Get first and last characters (quotes).
								let fchar = value.charAt(0);
								let lchar = value.charAt(value.length - 1);

								// Remove quotes and apply highlighting.
								value = `${chalk[c.def](fchar)}${chalk[
									c.string
								](
									// Remove start/closing quotes.
									value.slice(1, -1)
								)}${chalk[c.def](lchar)}`;
							}
							// Highlight everything but command-flags.
							else if (!/\$\(/.test(stripansi(value))) {
								// Highlight everything else.
								value = chalk[c.value](value);
							}
						}

						break;
					case "setting":
						value = `@${chalk[c.setting](value.slice(1))}`;

						break;
					case "comment":
						value = chalk[c.comment](value);

						break;
					case "command":
						// Highlight escaped sequences.
						value = value.replace(
							/(\\.)/g,
							`${chalk[c.escape]("$1")}`
						);
						// Make everything italic.
						value = chalk[c.i](value);

						break;
					case "flag":
						// Highlight flag name only (not bool '?' indicator).
						value = value.replace(
							/^([^\?]*?)(\??)$/g,
							`${chalk[c.flag]("$1")}$2`
						);

						break;
					case "shortcut":
						// Highlight escaped sequences.
						value = value.replace(
							/(\\.)/g,
							`${chalk[c.escape]("$1")}`
						);
						// Highlight everything else.
						value = chalk[c.shortcut](value);

						break;
					case "cmd-flag":
						// Highlight command-flag syntax: '$(' and ')'.
						value = value
							.replace(
								/^(\$)(\()/,
								`${chalk[c.cmdflag]("$1")}${chalk[c.def]("$2")}`
							)
							.replace(/(\))$/, `${chalk[c.def]("$1")}`);

						break;
					case "cmd-flag-arg":
						// Check if argument is a run-able command.
						let is_carg = /^\$/.test(value);

						// Remove '$' if argument is a run-able command.
						value = is_carg ? value.slice(1) : value;

						// Get first and last characters (quotes).
						let fchar = value.charAt(0);
						let lchar = value.charAt(value.length - 1);

						// Remove quotes and apply highlighting.
						value = `${is_carg ? chalk[c.def]("$") : ""}${chalk[
							c.def
						](fchar)}${chalk[c.string](
							// Remove start/closing quotes.
							value.slice(1, -1)
						)}${chalk[c.def](lchar)}`;

						break;
				}

				// Reset original array value with highlighted value.
				values[i] = value;
			}
		}
	}

	// Depending on what was provided, return single value or array of values.
	return is_singleton ? values[0] : values;
};
