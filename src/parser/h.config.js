"use strict";

/**
 * Build acdef config file contents from extracted settings.
 *
 * @param  {object} settings - The settings object.
 * @param  {array} header - The final file's header information.
 * @return {string} - The config file contents string.
 */
module.exports = () => {
	// Get highlighter.
	let h = global.$app.get("highlighter");
	let settings = global.$app.get("settings");
	let hsettings = global.$app.get("hsettings");
	let header = global.$app.get("header");
	let highlight = global.$app.get("highlight");

	// Store lines.
	let lines = [];
	let hlines = [];

	// If settings is empty return an empty string.
	if (!settings.__count__) {
		return "";
	}
	// Remove size/count key.
	delete settings.__count__;

	// [TODO] Possibly combine bottom loops into a single one.

	// Loop over settings to build config.
	for (let setting in settings) {
		if (settings.hasOwnProperty(setting)) {
			lines.push(`${setting} = ${settings[setting]}`);
		}
	}
	// Loop over highlighted settings config object.
	for (let hsetting in hsettings) {
		if (hsettings.hasOwnProperty(hsetting)) {
			hlines.push(`${hsetting} = ${hsettings[hsetting]}`);
		}
	}

	// Generate un-highlighted and highlighted acmaps.
	let content = [header]
		.concat(
			lines.sort(function(a, b) {
				return a.localeCompare(b);
			})
		)
		.join("\n")
		.replace(/\s*$/, "");
	let hcontent = [h(header, "comment")]
		.concat(
			hlines.sort(function(a, b) {
				return a.localeCompare(b);
			})
		)
		.join("\n")
		.replace(/\s*$/, "");

	return {
		content,
		hcontent,
		print: highlight ? hcontent : content
	};
};
