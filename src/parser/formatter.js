"use strict";

/**
 * Run final formatting logic on lines. Basically indents lines and removes
 *     unneeded new lines.
 *
 * @param  {array} lines - The list of lines to format into final string.
 * @param  {[type]} formatting - Array containing indentation char/amount.
 * @return {string} - The finally formatted string.
 */
module.exports = (lines, formatting) => {
	// If not formatting then return an empty string.
	if (!formatting) {
		return "";
	}

	// Vars - Indentation levels.
	let [indent_lvl1, indent_amount] = formatting;
	indent_lvl1 = indent_lvl1.repeat(indent_amount);
	let indent_lvl2 = indent_lvl1.repeat(2);

	let cformatted = []; // Cleaned/indented formatted array.
	let isempty = true;
	for (let i = 0, l = lines.length; i < l; i++) {
		// Cache current loop item.
		let data = lines[i];
		let [line, type, indentation_amount] = data;
		// Get previous line info.
		let pdata = lines[i - 1] || [];
		let [pline, ptype] = pdata;
		// Get next line info.
		let ndata = lines[i + 1] || [];
		let [nline, ntype] = ndata;

		// Determine indentation.
		let indentation = !indentation_amount
			? ""
			: indentation_amount === 1
			? indent_lvl1
			: indent_lvl2;

		// Avoid doing a future left trim by skipping starting newlines.
		if (isempty && type === "nl") {
			continue;
		} else {
			isempty = false;
		}

		// Skip empty lines after an opened command or before closing braces.
		if (type === "nl") {
			if (ptype === "nl" && /(close_brace)/.test(ntype)) {
				continue;
			} else if (
				((ptype === "flag_set" && pline.endsWith("(")) ||
					(ptype === "command" && pline.endsWith("["))) &&
				ntype === "nl"
			) {
				continue;
			}
		}

		// Add to cleaned, formatted array.
		cformatted.push(`${indentation}${line}`);
	}

	// Join final lines, right trim string, and return.
	return cformatted.join("").replace(/\n*$/g, "");
};
