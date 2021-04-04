"use strict";

const node = require("../helpers/nodes.js");
const error = require("../helpers/error.js");
const add = require("../helpers/tree-add.js");
const { nk } = require("../helpers/enums.js");
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
	let l = S.l;
	let state = "bullet";
	let type = "escaped";
	let N = node(nk.Option, S);
	let qchar = "";
	let comment = false;
	let braces = [];

	// Error if flag scope doesn't exist.
	bracechecks(S, null, "pre-existing-fs");

	let c,
		p = "";
	for (; S.i < l; S.i++, S.column++) {
		p = c;
		c = S.text.charAt(S.i);

		if (cin(C_NL, c)) {
			N.end = rollback(S) && S.i;
			break; // Stop at nl char.
		}

		if (c === "#" && p !== "\\" && (state !== "value" || comment)) {
			rollback(S);
			N.end = S.i;
			break;
		}

		switch (state) {
			case "bullet":
				N.bullet.start = N.bullet.end = S.i;
				N.bullet.value = c;
				state = "spacer";

				break;

			case "spacer":
				if (cnotin(C_SPACES, c)) error(S);
				state = "wsb-prevalue";

				break;

			case "wsb-prevalue":
				if (cnotin(C_SPACES, c)) {
					rollback(S);
					state = "value";
				}

				break;

			case "value":
				{
					if (!N.value.value) {
						// Determine value type.
						if (c === "$") type = "command-flag";
						else if (c === "(") {
							type = "list";
							braces.push(S.i);
						} else if (cin(C_QUOTES, c)) {
							type = "quoted";
							qchar = c;
						}

						N.value.start = N.value.end = S.i;
						N.value.value = c;
					} else {
						switch (type) {
							case "escaped":
								if (cin(C_SPACES, c) && p !== "\\") {
									state = "eol-wsb";
									continue;
								}

								break;

							case "quoted":
								if (c === qchar && p !== "\\") {
									state = "eol-wsb";
								} else if (c === "#" && !qchar) {
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
									if (
										N.value.value.length === 1 &&
										c !== "("
									) {
										error(S);
									}
								}

								// The following logic, is precursor validation
								// logic that ensures braces are balanced and
								// detects inline comment.
								if (p !== "\\") {
									if (c === "(" && !qchar) {
										braces.push(S.i);
									} else if (c === ")" && !qchar) {
										// If braces len is negative, opening
										// braces were never introduced so
										// current closing brace is invalid.
										if (!braces.length) {
											error(S);
										}
										braces.pop();
										if (!braces.length) {
											state = "eol-wsb";
										}
									}

									if (cin(C_QUOTES, c)) {
										if (!qchar) {
											qchar = c;
										} else if (qchar === c) {
											qchar = "";
										}
									}

									if (c === "#" && !qchar) {
										if (!braces.length) {
											comment = true;
											rollback(S);
										} else {
											S.column =
												braces.pop() -
												S.tables.linestarts[S.line];
											S.column++; // Add 1 to account for 0 base indexing.
											error(S);
										}
									}
								}
						}

						N.value.end = S.i;
						N.value.value += c;
					}
				}

				break;

			case "eol-wsb":
				if (cnotin(C_SPACES, c)) error(S);

				break;
		}
	}

	validate(S, N);
	add(S, N);
};
