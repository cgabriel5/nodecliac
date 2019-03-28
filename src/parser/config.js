"use strict";

/**
 * Build acdef config file contents from extracted settings.
 *
 * @param  {object} settings - The settings object.
 * @return {string} - The config file contents string.
 */
module.exports = (settings, header) => {
	// Store lines.
	let lines = [];

	// Loop over settings to build config.
	for (let setting in settings) {
		if (settings.hasOwnProperty(setting)) {
			lines.push(`${setting} = ${settings[setting]}`);
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
