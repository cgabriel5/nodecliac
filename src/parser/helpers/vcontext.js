"use strict";

const error = require("./error.js");
const { hasProp } = require("../../utils/toolbox.js");
const charsets = require("./charsets.js");
const { cin, cnotin, C_SPACES, C_CTX_ALL, C_CTX_MUT } = charsets;
const { C_CTX_FLG, C_CTX_CON, C_LETTERS, C_CTX_CAT, C_CTX_OPS } = charsets;

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

	// Ignore starting '"' and ending '"' when looping.
	let l = value.length - 1;
	while (i < l) {
		let char = value[i];
		if (cin(C_SPACES, char)) {
			i++;
			argument += char;
			continue;
		}
		if (cnotin(C_CTX_ALL, char)) {
			S.column = tindex(i);
			error(S, __filename);
		}
		if (char === ";") {
			// Track semicolons.
			if (is_empty_or_ws(argument)) {
				S.column = tindex(i);
				error(S, __filename, 14);
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
		error(S, __filename, 14);
	}

	/** Verifies that provided context string argument type is valid.
	 *     Something to note, the provided index is the index of the
	 *     first character of the argument. Therefore, if an error
	 *     is generated the amount of additional character indices
	 *     is added to the index.
	 *
	 * @param  {string} value - The string to verify.
	 * @param  {string} type - The verification type.
	 * @param  {number} i - The string's index.
	 * @return {string} - Error, else return value if valid.
	 */
	function verify(value, type, i) {
		let l = value.length;
		switch (type) {
			case "marg":
				if (value[0] === "-") {
					S.column = tindex(i);
					error(S, __filename);
				}

				break;

			case "carg":
				if (value[0] === "!") {
					if (l < 2) {
						S.column = tindex(i);
						error(S, __filename);
					}
					if (cnotin(C_LETTERS, value[1])) {
						S.column = tindex(i + 1);
						error(S, __filename);
					}
				} else {
					if (l < 1) {
						S.column = tindex(i);
						error(S, __filename);
					}
					if (cnotin(C_LETTERS, value[0])) {
						S.column = tindex(i + 1);
						error(S, __filename);
					}
				}

				break;

			case "ccond":
				if (value[0] === "#") {
					// Must be at least 5 chars in length.
					if (l < 5) {
						S.column = tindex(i);
						error(S, __filename);
					}
					if (cnotin(C_CTX_CAT, value[1])) {
						S.column = tindex(i + 1);
						error(S, __filename);
					}
					if (cnotin(C_CTX_OPS, value.substr(2, 2))) {
						S.column = tindex(i + 2);
						error(S, __filename);
					}
					// Characters at these indices must be
					// numbers if not, error.
					let nval = value.substr(4);
					if (!is_str_num(nval)) {
						S.column = tindex(i + 4);
						error(S, __filename);
					}
					// Error if number starts with 0.
					if (value[4] === "0" && nval.length !== 1) {
						S.column = tindex(i + 4);
						error(S, __filename);
					}
				} else {
					if (value[0] === "!") {
						if (l < 2) {
							S.column = tindex(i);
							error(S, __filename);
						}
						if (cnotin(C_LETTERS, value[1])) {
							S.column = tindex(i + 1);
							error(S, __filename);
						}
					} else {
						if (l < 1) {
							S.column = tindex(i);
							error(S, __filename);
						}
						if (cnotin(C_LETTERS, value[0])) {
							S.column = tindex(i + 1);
							error(S, __filename);
						}
					}
				}

				break;
		}
		return value;
	}

	let resume_index = 1; // Account for initial skipped quote.
	let values = [];
	// Validate parsed arguments.
	for (let c = 0, x = 0, l = args.length; x < l; x++, c++) {
		let arg = args[x];
		let i = 0;
		let l = arg.length;
		let fchar = "";

		// Mutual exclusive variables.
		let marg = "";
		let margs = [];
		let mopen_br_index = 0;
		let mclose = false;
		let del_pipe = [];
		let mindices = [];

		// Conditional variables.
		let hasconds = false;
		let del_cfcomma = [];
		let cflags = [];
		let cfindices = [];
		let carg = "";
		//
		let del_cncomma = [];
		let cconds = [];
		let ccindices = [];
		let ccond = "";

		while (i < l) {
			let char = arg[i];
			if (cin(C_SPACES, char)) {
				i++;
				resume_index++;
				continue;
			}

			if (fchar === "") {
				fchar = char;
				if (fchar === "{") {
					mopen_br_index = resume_index;
					i++;
					resume_index++;
					continue;
				}
			}

			// Mutual exclusivity.
			if (fchar === "{") {
				if (cnotin(C_CTX_MUT, char)) {
					S.column = tindex(resume_index);
					error(S, __filename);
				}

				// Braces were closed but nws char found.
				if (mclose && cnotin(C_SPACES, char)) {
					S.column = tindex(resume_index);
					error(S, __filename);
				}

				if (char === "}") {
					mclose = true;
					i++;
					resume_index++;
					continue;
				}

				if (char === "|") {
					if (is_empty_or_ws(marg)) {
						S.column = tindex(resume_index);
						error(S, __filename, 14);
					}
					del_pipe.push(resume_index);
					margs.push(
						verify(marg, "marg", mindices[mindices.length - 1])
					);
					marg = "";
					i++;
					resume_index++;
					continue;
				}

				if (marg === "") {
					mindices.push(resume_index);
				}
				marg += char;
			} else {
				// Conditionals.
				if (hasconds === false) {
					if (cnotin(C_CTX_FLG, char)) {
						S.column = tindex(resume_index);
						error(S, __filename);
					}

					if (char === ",") {
						if (is_empty_or_ws(carg)) {
							S.column = tindex(resume_index);
							error(S, __filename);
						}
						del_cfcomma.push(resume_index);
						cflags.push(
							verify(
								carg,
								"carg",
								cfindices[cfindices.length - 1]
							)
						);
						carg = "";
						i++;
						resume_index++;
						continue;
					} else if (char === ":") {
						hasconds = true;
						if (carg && cflags.length === 0) {
							cflags.push(
								verify(
									carg,
									"carg",
									cfindices[cfindices.length - 1]
								)
							);
							carg = "";
						}
						if (cflags.length === 0) {
							S.column = tindex(resume_index);
							error(S, __filename); // No flags.
						}
						i++;
						resume_index++;
						continue;
					}

					if (carg === "") {
						cfindices.push(resume_index);
					}
					carg += char;
				} else {
					if (cnotin(C_CTX_CON, char)) {
						S.column = tindex(resume_index);
						error(S, __filename);
					}
					// If it's not the first character, error.
					if (-~["!", "#"].indexOf(char) && ccond) {
						S.column = tindex(resume_index);
						error(S, __filename);
					} else if (char === ",") {
						if (is_empty_or_ws(ccond)) {
							S.column = tindex(resume_index);
							error(S, __filename, 14);
						}
						del_cncomma.push(resume_index);
						cconds.push(
							verify(
								ccond,
								"ccond",
								ccindices[ccindices.length - 1]
							)
						);
						ccond = "";
						i++;
						resume_index++;
						continue;
					}

					if (ccond === "") {
						ccindices.push(resume_index);
					}
					ccond += char;
				}
			}
			i++;
			resume_index++;
		}
		// Add 1 to account for ';' delimiter.
		i++;
		resume_index++;

		if (fchar === "{") {
			// Check that braces were closed.
			if (mclose === false) {
				S.column = tindex(mopen_br_index);
				error(S, __filename, 17);
			}

			// Check if mutual exclusive braces are empty.
			if (marg === "") {
				if (margs.length === 0) {
					S.column = tindex(mopen_br_index);
					error(S, __filename);
				}
			} else {
				margs.push(verify(marg, "marg", mindices[mindices.length - 1]));
			}

			// Error if a trailing '|' delimiter exists.
			if (del_pipe.length >= margs.length) {
				// Find first trailing semicolon delimiter.
				let pindex =
					del_pipe.length === margs.length
						? del_pipe[del_pipe.length - 1]
						: del_pipe[margs.length - 1 + 1];
				S.column = tindex(pindex);
				error(S, __filename, 14);
			}

			// Build cleaned value string.
			values.push("{" + margs.join("|") + "}");
		} else {
			// Get last argument.
			if (carg) {
				cflags.push(
					verify(carg, "carg", cfindices[cfindices.length - 1])
				);
			}
			if (ccond) {
				cconds.push(
					verify(ccond, "ccond", ccindices[ccindices.length - 1])
				);
			}

			// Error if a trailing flag ',' delimiter exists.
			if (del_cfcomma.length > 0 && del_cfcomma.length >= cflags.length) {
				// Find first trailing semicolon delimiter.
				let dindex =
					del_cfcomma.length === cflags.length
						? del_cfcomma[del_cfcomma.length - 1]
						: del_cfcomma[cflags.length - 1 + 1];
				S.column = tindex(dindex);
				error(S, __filename, 14);
			}

			// Error if a trailing conditions ',' delimiter exists.
			if (del_cncomma.length > 0 && del_cncomma.length >= cconds.length) {
				// Find first trailing semicolon delimiter.
				let dindex =
					del_cncomma.length === cconds.length
						? del_cncomma[del_cncomma.length - 1]
						: del_cncomma[cconds.length - 1 + 1];
				S.column = tindex(dindex);
				error(S, __filename, 14);
			}

			// If flags exist but conditions don't, error.
			if (cflags.length > 1 && cconds.length === 0) {
				let dindex =
					del_semicolon.length > 0
						? del_semicolon[c] - 1
						: value.length - 1 - 1; // Else, use val length.
				S.column = tindex(dindex);
				error(S, __filename, 16);
			}

			// Build cleaned value string.
			if (cflags.length > 0) {
				var val = cflags.join(",");
				if (cconds.length > 0) {
					val += ":" + cconds.join(",");
				}
				values.push(val);
			}
		}
	}

	return qchar + values.join(";") + qchar;
};
