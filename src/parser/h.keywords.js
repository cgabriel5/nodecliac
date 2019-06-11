"use strict";

/**
 * Build acdef command chain default definitions.
 *
 * @param  {object} keywords - The keywords object.
 * @param  {array} header - The final file's header information.
 * @return {object} - Object containing highlighted/non-highlighted defaults.
 */
module.exports = () => {
	// Get highlighter.
	let h = global.$app.get("highlighter");
	let s = global.$app.get("stripansi");
	let keywords = global.$app.get("keywords");
	let hkeywords = global.$app.get("hkeywords");
	let header = "\n"; // Set header to a new line.
	let commandname = global.$app.get("commandname");
	let highlight = global.$app.get("highlight");

	// Store lines.
	let lines = [];
	let hlines = [];

	// RegExp to match main command/first command in chain to remove.
	let r = new RegExp(
		// Note: Properly escape '+' characters for commands like 'g++'.
		`^(${commandname.replace(/(\+)/g, "\\$1")}|[-_a-zA-Z0-9]+)`
	);

	// If keywords object is empty return "empty" object (just headers).
	if (!keywords.__count__) {
		return {
			content: "",
			hcontent: "",
			print: ""
		};
	}
	// Remove size/count key.
	delete keywords.__count__;

	// [TODO] Possibly combine bottom loops into a single one.

	// Loop over keywords to build config.
	for (let chain in keywords) {
		if (keywords.hasOwnProperty(chain)) {
			// Get keyword value.
			let [keyword, value] = keywords[chain];

			// Remove the main command from the command chain. However,
			// when the command name is not the main command in (i.e.
			// when running on a test file) just remove the first command
			// name in the chain.
			chain = chain.replace(r, "");

			// Store keyword/value line.
			lines.push(`${chain} ${keyword}${value ? " " + value : ""}`);
		}
	}

	// Loop over highlighted keywords config object.
	for (let chain in hkeywords) {
		if (hkeywords.hasOwnProperty(chain)) {
			// Get keyword value.
			let [hkeyword, hvalue] = hkeywords[chain];

			// Remove the main command from the command chain. However,
			// when the command name is not the main command in (i.e.
			// when running on a test file) just remove the first command
			// name in the chain.
			chain = h(chain.replace(r, ""), "command");

			// Store keyword/value line.
			hlines.push(`${chain} ${hkeyword}${hvalue ? " " + hvalue : ""}`);
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
	let hcontent = [header]
		.concat(hlines.sort(aplhasort))
		.join("\n")
		.replace(/\s*$/, "");

	return {
		content,
		hcontent,
		print: highlight ? hcontent : content
	};
};
