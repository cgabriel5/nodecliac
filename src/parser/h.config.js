"use strict";

/**
 * Build acdef config file contents from extracted settings.
 *
 * @param  {object} settings - The settings object.
 * @param  {array} header - The final file's header information.
 * @return {string} - The config file contents string.
 */
module.exports = (settings, header) => {
	// Get highlighter.
	const h = global.$app.get("highlighter");

	// Store lines.
	let lines = [];

	// If settings is empty return an empty string.
	if (!settings.__count__) {
		return "";
	}
	// Remove size/count key.
	delete settings.__count__;

	// Loop over settings to build config.
	for (let setting in settings) {
		if (settings.hasOwnProperty(setting)) {
			// Add syntax highlighting to setting then store setting:value.
			lines.push(`${h(setting, "setting")} = ${settings[setting]}`);
		}
	}

	// Add header to lines and return final lines.
	return header
		.concat(
			lines.sort(function(a, b) {
				return a.localeCompare(b);
			})
		)
		.join("\n")
		.replace(/\s*$/, "");
};
