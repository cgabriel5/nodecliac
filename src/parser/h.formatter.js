"use strict";

/**
 * Run final formatting logic on lines. Basically indents lines and removes
 *     unneeded new lines.
 *
 * @param  {array} lines - The list of lines to format into final string.
 * @param  {array} formatting - Array containing indentation char/amount.
 * @param  {boolean} stripcomments - Flag indicating whether to remove
 *     comments or not.
 * @return {string} - The finally formatted string.
 */
module.exports = preformat => {
	// Get params.
	let { lines, hlines } = preformat;

	// Get globals.
	let formatting = global.$app.get("formatting");
	let stripcomments = global.$app.get("stripcomments");
	let highlight = global.$app.get("highlight");

	// If not formatting then return an empty string.
	if (!formatting) {
		return "";
	}

	// Vars - Indentation levels.
	let [indent_lvl1, indent_amount] = formatting;
	indent_lvl1 = indent_lvl1.repeat(indent_amount);
	let indent_lvl2 = indent_lvl1.repeat(2);

	let cformatted = []; // Cleaned/indented formatted array.
	let hcformatted = []; // Highlighted version.
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
		let [, /*nline*/ ntype] = ndata;
		// Get next line info.
		let ndata2 = lines[i + 2] || [];
		let [, /*nline2*/ ntype2] = ndata2;

		// Get highlighted data.
		let [hline] = hlines[i];

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

		// Skip empty lines for following scenarios.
		if (type === "nl") {
			if (
				(ptype === "nl" && /(close-brace|flag-option)/.test(ntype)) ||
				// Note: This scenario, in some cases, removes the needed new
				// line which separates the flagset > \n > flag-option lines.
				// This will get amended below. The scenario in question is:
				// '--flag=(\n- val', for example.
				(((ptype === "flag-set" && pline.endsWith("(")) ||
					(ptype === "command" && pline.endsWith("["))) &&
					ntype === "nl")
			) {
				continue;
			}

			// Run further newline checks when 'strip-comments' flag is set.
			if (stripcomments) {
				if (
					ptype === "flag-set" &&
					ntype === "nl" &&
					ntype2 !== "close-brace"
				) {
					continue;
				} else if (
					ptype === "flag-option" &&
					ntype === "nl" &&
					ntype2 === "flag-option"
				) {
					continue;
				}
			}
		}

		// Note: When skipping new lines (above) a needed new line separating
		// the flagset > \n > flag-option lines in some cases removed. This
		// will amend this special flag-option scenario.
		if (type === "flag-option") {
			// If last item in formatted array is the parent flag set and
			// not a new line then we append a new line.
			if (cformatted[cformatted.length - 1] !== "\n") {
				cformatted.push("\n");
				hcformatted.push("\n");
			}
		}

		// Add to cleaned, formatted array.
		cformatted.push(`${indentation}${line}`);
		// Add to cleaned, formatted array.
		hcformatted.push(`${indentation}${hline}`);
	}

	// Generate un-highlighted and highlighted formatted acmaps.
	let content = cformatted.join("").replace(/\n*$/g, "");
	let hcontent = hcformatted.join("").replace(/\n*$/g, "");

	return {
		content,
		hcontent,
		print: highlight ? hcontent : content
	};
};
