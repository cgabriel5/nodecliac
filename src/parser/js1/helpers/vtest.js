"use strict";

const error = require("./error.js");
const { hasProp } = require("../../utils/toolbox.js");
const charsets = require("./charsets.js");
const { cin, cnotin, C_SPACES, C_LETTERS, C_CTX_CTT, C_CTX_OPS } = charsets;

/**
 * Checks if s is empty or consists entirely of whitespace characters.
 *
 * @param  {string} s - The string to check.
 * @return {boolean} - True if checks passed.
 */
function is_empty_or_ws(s) {
	for (let i = 0, l = s.length; i < l; i++) {
		if (cnotin(C_SPACES, s[i])) return false;
	}
	return true;
}

/**
 * Checks if s only contains number characters.
 *
 * @param  {string} s - The string to check.
 * @return {boolean} - True if checks passed.
 * @source [https://stackoverflow.com/a/51085077]
 */
function is_str_num(s) {
	for (let i = s.length - 1; i >= 0; i--) {
		const d = s.charCodeAt(i);
		// 48/57 are char codes to 0/9, respectively.
		if (d < 48 || d > 57) return false;
	}
	return true;
}

/**
 * Validate the provided context string.
 *
 * @param  {object} S -State object.
 * @param  {string} value - The context string.
 * @param  {object} vindices - The variable object indices.
 * @param  {number} resumepoint - The index loop resume point.
 * @return {string} - The cleaned context string.
 */
module.exports = (S, value, vindices, resumepoint) => {
	/**
	 * Create a range object.
	 *
	 * @param  {number} s - Start range.
	 * @param  {number} e - Range end.
	 * @return {object} - The range object.
	 * @source [https://dev.to/kerafyrm02/comment/ai8e]
	 */
	let range = function (s, e) {
		const amount = "x".repeat(e - s + 1);
		return Array.from(amount, (_, i) => s + i);
	};

	/**
	 * Return true index by accounting for expanded variables.
	 *     If a context string uses variables the string will
	 *     be expanded. This will then cause the original and
	 *     expanded strings to separate in character indices.
	 *     This function takes the expanded character index,
	 *     figures out its unexpanded index, and returns it.
	 *
	 * @param  {number} i - The index.
	 * @return {number} - The true index.
	 */
	function tindex(index) {
		let i = index;
		let vindex = 0;
		let vsublen = 0;
		for (const k in vindices) {
			const [ind, sl] = vindices[k];
			if (k <= index && i > k) {
				i = i + ind;
				vindex = k * 1;
				vsublen = sl * 1;
			}
		}

		// Final check: If index at this point is found in between
		// a variable start/end position, reset the index to the
		// start of the variable position.
		//
		// Note: Range must be at greater than the variable syntax.
		if (vindex + vsublen > 3) {
			// Account for '${}' chars.
			let r = range(vindex, vindex + vsublen + 1);
			if (hasProp(r, i)) i = vindex;
		}
		return i + resumepoint;
	}

	let argument = "";
	let args = [];
	let qchar = value.charAt(0);
	let i = 1; // Account for '"'.
	let del_semicolon = [];
	let aindices = [];
	let findex = 0;

	// Ignore starting '"' and ending '"' when looping.
	let l = value.length - 1;
	while (i < l) {
		let char = value[i];
		if (cin(C_SPACES, char)) {
			i++;
			argument += char;
			continue;
		} else {
			if (!findex) findex = i;
		}
		// Handle escaped characters.
		if (char === "\\") {
			if (value[i + 1]) {
				argument += char + value[i + 1];
				i += 2;
				continue;
			}
		}
		if (char === ";") {
			// Track semicolons.
			if (is_empty_or_ws(argument)) {
				S.column = tindex(i);
				error(S, 14);
			}
			del_semicolon.push(i);
			args.push(argument);
			argument = "";
			i++;
			continue;
		}
		aindices.push(i);
		argument += char;
		i++;
	}
	// Get last argument.
	if (!is_empty_or_ws(argument)) {
		aindices.push(i);
		args.push(argument);
	}

	// Error if a trailing ';' delimiter exists.
	if (del_semicolon.length > 0 && del_semicolon.length >= args.length) {
		// Find first trailing semicolon delimiter.
		let dindex =
			del_semicolon.length === args.length
				? del_semicolon[del_semicolon.length - 1]
				: del_semicolon[args.length - 1 + 1];
		S.column = tindex(dindex);
		error(S, 14);
	}

	/** Verifies that provided context string argument type is valid.
	 *     Something to note, the provided index is the index of the
	 *     first character of the argument. Therefore, if an error
	 *     is generated the amount of additional character indices
	 *     is added to the index.
	 *
	 * @param  {string} value - The string to verify.
	 * @param  {number} i - The string's index.
	 * @return {string} - Error, else return value if valid.
	 */
	function verify(value, i) {
		let v = value;
		let l = value.length;
		// Inversion: Remove '!' for next checks.
		if (v[0] === "!") v = v.slice(1);
		if (v[0] === "#") {
			// Must be at least 5 chars in length.
			if (l < 5) {
				S.column = tindex(i);
				error(S);
			}
			if (cnotin(C_CTX_CTT, v[1])) {
				S.column = tindex(i + 1);
				error(S);
			}
			if (cnotin(C_CTX_OPS, v.substr(2, 2))) {
				S.column = tindex(i + 2);
				error(S);
			}
			// Characters at these indices must be
			// numbers if not, error.
			let nval = v.substr(4);
			if (!is_str_num(nval)) {
				S.column = tindex(i + 4);
				error(S);
			}
			// Error if number starts with 0.
			if (v[4] === "0" && nval.length !== 1) {
				S.column = tindex(i + 4);
				error(S);
			}
		} else {
			if (l < 1) {
				S.column = tindex(i);
				error(S);
			}
			if (cnotin(C_LETTERS, v[0])) {
				S.column = tindex(i + 1);
				error(S);
			}
		}
		return value;
	}

	// Check that test string starts with main command.
	if (!args[0].trim().startsWith(S.tables.variables.COMMAND)) {
		S.column = tindex(findex);
		error(S, 15);
	}

	// Account for initial skipped quote/test string.
	let resume_index = !args.length ? 1 : args[0].length + 1;
	let values = [args[0].trimStart()]; // Store before shifting.
	args.shift(); // Remove test string.
	// Validate parsed arguments.
	for (let x = 0, l = args.length; x < l; x++) {
		let arg = args[x];
		let i = 0;
		let l = arg.length;
		let fchar = "";
		let findex = 0;

		while (i < l) {
			let char = arg[i];
			if (cin(C_SPACES, char)) {
				i++;
				resume_index++;
				continue;
			}

			if (fchar === "") {
				fchar = char;
				findex = i;
			}

			i++;
			resume_index++;

			// Only #ceq3 and its inversion (!#ceq3) are validated.
			if (fchar === "#" || fchar === "!") {
				if (fchar === "!" && !(l > 2 && arg[findex + 1] === "#")) {
					continue;
				}
				arg = verify(arg.trim(), resume_index);
				break;
			}
		}

		values.push(arg.trim());

		// Add 1 to account for ';' delimiter.
		i++;
		resume_index++;
	}

	return qchar + values.join(";") + qchar;
};
