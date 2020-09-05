"use strict";

const node = require("../helpers/nodes.js");
const add = require("../helpers/tree-add.js");
const error = require("../helpers/error.js");
const rollback = require("../helpers/rollback.js");
const validate = require("../helpers/validate.js");
const bracechecks = require("../helpers/brace-checks.js");
const {
	cin,
	cnotin,
	C_NL,
	C_SPACES,
	C_QUOTES
} = require("../helpers/charsets.js");

/**
 * ----------------------------------------------------------- Parsing Breakdown
 * - value
 *  |     ^-EOL-Whitespace-Boundary 2
 *  ^-Whitespace-Boundary 1
 * ^-Bullet
 *  ^-Value
 * -----------------------------------------------------------------------------
 *
 * @param  {object} S - State object.
 * @return {undefined} - Nothing is returned.
 */
module.exports = (S) => {
	let { l, text } = S;
	let state = "bullet";
	let type = "escaped";
	let N = node(S, "OPTION");
	let qchar = "";
	let comment = false;
	let braces = [];

	// Error if flag scope doesn't exist.
	bracechecks(S, null, "pre-existing-fs");

	let char, pchar = "";
	for (; S.i < l; S.i++, S.column++) {
		pchar = char;
		char = text.charAt(S.i);

		if (cin(C_NL, char)) {
			N.end = rollback(S) && S.i;
			break; // Stop at nl char.
		}

		if (char === "#" && pchar !== "\\" && (state !== "value" || comment)) {
			rollback(S);
			N.end = S.i;
			break;
		}

		switch (state) {
			case "bullet":
				N.bullet.start = N.bullet.end = S.i;
				N.bullet.value = char;
				state = "spacer";

				break;

			case "spacer":
				if (cnotin(C_SPACES, char)) error(S, __filename);
				state = "wsb-prevalue";

				break;

			case "wsb-prevalue":
				if (cnotin(C_SPACES, char)) {
					rollback(S);
					state = "value";
				}

				break;

			case "value":
				{
					if (!N.value.value) {
						// Determine value type.
						if (char === "$") type = "command-flag";
						else if (char === "(") {
							type = "list";
							braces.push(S.i);
						} else if (cin(C_QUOTES, char)) {
							type = "quoted";
							qchar = char;
						}

						N.value.start = N.value.end = S.i;
						N.value.value = char;
					} else {
							switch (type) {
								case "escaped":
									if (cin(C_SPACES, char) && pchar !== "\\") {
										state = "eol-wsb";
										continue;
									}

									break;

								case "quoted":
									if (char === qchar && pchar !== "\\") {
										state = "eol-wsb";
									} else if (char === "#" && !qchar) {
										comment = true;
										rollback(S);
									}

									break;

								default:
									// list|command-flag
									// The following character after the initial
									// '$' must be a '('. If it does not follow,
									// error.
									//   --help=$"cat ~/files.text"
									//   --------^ Missing '(' after '$'.
									if (type === "command-flag") {
										if (N.value.value.length === 1 && char !== "(") {
											error(S, __filename);
										}
									}

									// The following logic, is precursor validation
									// logic that ensures braces are balanced and
									// detects inline comment.
									if (pchar !== "\\") {
										if (char === "(" && !qchar) {
											braces.push(S.i);
										} else if (char === ")" && !qchar) {
											// If braces len is negative, opening
											// braces were never introduced so
											// current closing brace is invalid.
											if (!braces.length) {
												error(S, __filename); }
											braces.pop();
											if (!braces.length) {
												state = "eol-wsb"; }
										}

										if (cin(C_QUOTES, char)) {
											if (!qchar) {
												qchar = char;
											}
											else if (qchar === char) {
												qchar = "";
											}
										}

										if (char === "#" && !qchar) {
											if (!braces.length) {
												comment = true;
												rollback(S);
											} else {
												S.column = braces.pop() - S.tables.linestarts[S.line];
												S.column++; // Add 1 to account for 0 base indexing.
												error(S, __filename);
											}
										}
									}
							}

							N.value.end = S.i;
							N.value.value += char;
						}
				}

				break;

			case "eol-wsb":
				if (cnotin(C_SPACES, char)) error(S, __filename);

				break;
		}
	}

	validate(S, N);
	add(S, N);
};
