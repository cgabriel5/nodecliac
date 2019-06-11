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
	let s = global.$app.get("stripansi");
	let settings = global.$app.get("settings");
	let hsettings = global.$app.get("hsettings");
	let header = global.$app.get("header");
	let highlight = global.$app.get("highlight");

	// Store lines.
	let lines = [];
	let hlines = [];

	// If settings object is empty return "empty" object (just headers).
	if (!settings.__count__) {
		return {
			content: header,
			hcontent: h(header, "comment"),
			print: highlight ? h(header, "comment") : header
		};
	}
	// Remove size/count key.
	delete settings.__count__;

	// [TODO] Possibly combine bottom loops into a single one.

	// Loop over settings to build config.
	for (let setting in settings) {
		if (settings.hasOwnProperty(setting)) {
			// Get setting value.
			let value = settings[setting];
			// Store setting/value line.
			lines.push(`${setting}${value ? " = " + value : ""}`);
		}
	}
	// Loop over highlighted settings config object.
	for (let hsetting in hsettings) {
		if (hsettings.hasOwnProperty(hsetting)) {
			// Get setting value.
			let hvalue = hsettings[hsetting];
			// Store setting/value line.
			hlines.push(`${hsetting}${hvalue ? " = " + hvalue : ""}`);
		}
	}

	/**
	 * Sort function.
	 *
	 * @param  {string} a - Item a.
	 * @param  {string} b - Item b.
	 * @return {number} - The sort number result.
	 */
	let aplhasort = (a, b) => {
		// Remove ansi coloring before sorting.
		return s(a).localeCompare(s(b));
	};

	// Generate un-highlighted and highlighted acmaps.
	let content = [header]
		.concat(lines.sort(aplhasort))
		.join("\n")
		.replace(/\s*$/, "");
	let hcontent = [h(header, "comment")]
		.concat(hlines.sort(aplhasort))
		.join("\n")
		.replace(/\s*$/, "");

	return {
		content,
		hcontent,
		print: highlight ? hcontent : content
	};
};
