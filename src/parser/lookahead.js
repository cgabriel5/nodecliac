"use strict";

/**
 * Does 1 of two things. Either looks ahead and captures all characters
 *     until provided RegExp fails or captures all characters until
 *     RegExp passed. The latter method may be used to capture all
 *     characters for a line, for example.
 *
 * @param  {number} index - The index offset to start capturing/testing.
 * @param  {string} input - The string to test.
 * @param  {regexp} r - The RegExp object to test characters against.
 * @param  {number} rcount - Optional amount of characters to capture.
 * @return {object} - Object containing passing/failing chars and
 *     starting/ending capture indices.
 *
 * Examples:
 * - Return all chars until RegExp is matched. Example will return all
 *     characters until newline char is found.
 * lookahead(2, "Some text.", new RegExp("\\r?\\n"));
 * - Return n chars (in this case 1) that match RegExp.
 * lookahead(2, "Some text.", new RegExp("[a-zA-Z]"), 1);
 */
module.exports = (index, input, r, rcount) => {
	let chars = []; // RegExp passing chars.
	let chars_str = ""; // chars in string form.
	let xchars = []; // RegExp excluded chars.
	let xchars_str = ""; // xchars in string form.
	let sindex, eindex;

	// Check if return character count was provided.
	let rexists = rcount !== undefined;

	// Start looping string at provided index offset.
	for (let i = index, l = input.length; i < l; i++) {
		// Cache current loop item.
		let char = input[i];

		if (rexists) {
			// Once counter hits 0 all needed characters were captured.
			if (!rcount) {
				break;
			}

			// Test current character against provided RegExp.
			if (r.test(char)) {
				// Set starting match index if not already set.
				if (!sindex) {
					sindex = i;
				}

				// If character passes RegExp then add to passed array.
				chars.push(char);
				// Append to string.
				chars_str += char;

				// Decrease counter.
				if (rexists) {
					rcount--;

					// Set ending match index.
					eindex = i;
				}
			} else {
				// Set starting match index if not already set.
				if (!sindex) {
					sindex = i;
				}

				// Set ending match index.
				eindex = i;

				// Store failing characters.
				xchars.push(char);
				// Append to string.
				xchars_str += char;

				// Exit loop once RegExp fails.
				break;
			}
		} else {
			// This will capture all chars until RegExp matches.

			// Test current character against provided RegExp.
			if (!r.test(char)) {
				// Set starting match index if not already set.
				if (!sindex) {
					sindex = i;
				}

				// If character fails RegExp add to passed array.
				chars.push(char);
				// Append to string.
				chars_str += char;
			} else {
				// Set ending match index.
				eindex = i;

				// Store passing match.
				xchars.push(char);
				// Append to string.
				xchars_str += char;

				// Once RegExp passes we break.
				break;
			}
		}
	}

	// If glob until method was used and the contents does not contain
	// the ending character then we set the end index to that of the
	// input's length.
	if (!eindex && !rexists) {
		eindex = input.length;
	}

	return {
		chars,
		xchars,
		indices: [sindex, eindex],
		chars_str,
		xchars_str
	};
};
