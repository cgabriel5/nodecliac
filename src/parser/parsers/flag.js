"use strict";

const node = require("../helpers/nodes.js");
const error = require("../helpers/error.js");
const add = require("../helpers/tree-add.js");
const { nk } = require("../helpers/enums.js");
const rollback = require("../helpers/rollback.js");
const validate = require("../helpers/validate.js");
const charsets = require("../helpers/charsets.js");
const { cin, cnotin, C_NL, C_SPACES, C_LETTERS } = charsets;
const { C_QUOTES, C_FLG_IDENT, C_KW_ALL, C_KD_STR } = charsets;

/**
 * ----------------------------------------------------------- Parsing Breakdown
 * --flag
 * --flag ?
 * --flag =* "string"
 * --flag =* 'string'
 * --flag =  $(flag-command)
 * --flag =  (flag-options-list)
 *       | |                    ^-EOL-Whitespace-Boundary 3.
 *       ^-^-Whitespace-Boundary 1/2.
 * ^-Symbol.
 *  ^-Name.
 *        ^-Assignment.
 *           ^-Value.
 * -----------------------------------------------------------------------------
 *
 * @param  {object} S - State object.
 * @param  {string} isoneliner - Whether to treat flag as a oneliner.
 * @return {object} - Node object.
 */
module.exports = (S, isoneliner) => {
	let l = S.l;
	let state = S.text.charAt(S.i) === "-" ? "hyphen" : "keyword";
	let stop; // Flag: true - stops parser.
	let type = "escaped";
	let N = node(nk.Flag, S);
	let alias = false;
	let qchar = "";
	let comment = false;
	let braces = [];

	// If not a oneliner or no command scope, flag is being declared out of scope.
	if (!(isoneliner || S.scopes.command)) error(S, 10);

	// If flag scope already exists another flag cannot be declared.
	if (S.scopes.flag) error(S, 11);

	let c,
		p = "";
	for (; S.i < l; S.i++, S.column++) {
		p = c;
		c = S.text.charAt(S.i);

		if (stop || cin(C_NL, c)) {
			N.end = rollback(S) && S.i;
			break; // Stop at nl char.
		}

		if (c === "#" && p !== "\\" && (state !== "value" || comment)) {
			rollback(S);
			N.end = S.i;
			break;
		}

		switch (state) {
			case "hyphen":
				// [https://stackoverflow.com/a/25895905]
				// [https://stackoverflow.com/a/12281034]
				// RegEx to split on unescaped '|': /(?<=[^\\]|^|$)\|/

				if (!N.hyphens.value) {
					if (c !== "-") error(S);
					N.hyphens.start = N.hyphens.end = S.i;
					N.hyphens.value = c;
				} else {
					if (c !== "-") {
						state = "name";
						rollback(S);
					} else {
						N.hyphens.end = S.i;
						N.hyphens.value += c;
					}
				}

				break;

			case "keyword":
				{
					let keyword_len = 7;
					let endpoint = keyword_len - 1;
					let keyword = S.text.substr(S.i, keyword_len);

					// Keyword must be allowed.
					if (!-~C_KW_ALL.indexOf(keyword)) error(S);
					N.keyword.start = S.i;
					N.keyword.end = S.i + endpoint;
					N.keyword.value = keyword;
					state = "keyword-spacer";

					// Note: Forward indices to skip keyword chars.
					S.i += endpoint;
					S.column += endpoint;
				}

				break;

			case "keyword-spacer":
				if (cnotin(C_SPACES, c)) error(S);
				state = "wsb-prevalue";

				break;

			case "name":
				if (!N.name.value) {
					if (cnotin(C_LETTERS, c)) error(S);
					N.name.start = N.name.end = S.i;
					N.name.value = c;
				} else {
					if (cin(C_FLG_IDENT, c)) {
						N.name.end = S.i;
						N.name.value += c;
					} else if (c === ":" && !alias) {
						state = "alias";
						rollback(S);
					} else if (c === "=") {
						state = "assignment";
						rollback(S);
					} else if (c === ",") {
						state = "delimiter";
						rollback(S);
					} else if (c === "?") {
						state = "boolean-indicator";
						rollback(S);
					} else if (c === "|") {
						state = "pipe-delimiter";
						rollback(S);
					} else if (cin(C_SPACES, c)) {
						state = "wsb-postname";
						rollback(S);
					} else error(S);
				}

				break;

			case "wsb-postname":
				if (cnotin(C_SPACES, c)) {
					if (c === "=") {
						state = "assignment";
						rollback(S);
					} else if (c === ",") {
						state = "delimiter";
						rollback(S);
					} else if (c === "|") {
						state = "pipe-delimiter";
						rollback(S);
					} else error(S);
				}

				break;

			case "boolean-indicator":
				N.boolean.start = N.boolean.end = S.i;
				N.boolean.value = c;
				state = "pipe-delimiter";

				break;

			case "alias":
				{
					alias = true;
					// Next char must also be a colon.
					let n = S.text.charAt(S.i + 1);
					if (n !== ":") error(S);
					N.alias.start = S.i;
					N.alias.end = S.i + 2;

					let letter = S.text.charAt(S.i + 2);
					if (cnotin(C_LETTERS, letter)) {
						S.i += 1;
						S.column += 1;
						error(S);
					}

					N.alias.value = letter;
					state = "name";

					// Note: Forward indices to skip alias chars.
					S.i += 2;
					S.column += 2;
				}

				break;

			case "assignment":
				N.assignment.start = N.assignment.end = S.i;
				N.assignment.value = c;
				state = "multi-indicator";

				break;

			case "multi-indicator":
				if (c === "*") {
					N.multi.start = N.multi.end = S.i;
					N.multi.value = c;
					state = "wsb-prevalue";
				} else {
					if (c === "|") state = "pipe-delimiter";
					else if (c === ",") state = "delimiter";
					else state = "wsb-prevalue";
					rollback(S);
				}

				break;

			case "pipe-delimiter":
				if (cnotin(C_SPACES, c)) {
					// Note: If char is not a pipe or if the flag is not a
					// oneliner flag and there are more characters after the
					// flag error. Example:
					// * = [
					// 		--help?|context "!help: #fge1"
					// ]
					if (c !== "|" || !isoneliner) error(S);
					stop = true;
				}

				break;

			case "delimiter":
				N.delimiter.start = N.delimiter.end = S.i;
				N.delimiter.value = c;
				state = "eol-wsb";

				break;

			case "wsb-prevalue":
				if (cnotin(C_SPACES, c)) {
					let keyword = !-~C_KD_STR.indexOf(N.keyword.value);
					if (c === "|" && keyword) state = "pipe-delimiter";
					else if (c === ",") state = "delimiter";
					else state = "value";
					rollback(S);
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
						if (
							c === "|" &&
							!-~C_KD_STR.indexOf(N.keyword.value) &&
							p !== "\\"
						) {
							state = "pipe-delimiter";
							rollback(S);
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
											if (!qchar) qchar = c;
											else if (qchar === c) qchar = "";
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
				}

				break;

			case "eol-wsb":
				if (
					c === "|" &&
					!-~C_KD_STR.indexOf(N.keyword.value) &&
					p !== "\\"
				) {
					state = "pipe-delimiter";
					rollback(S);
				} else if (cnotin(C_SPACES, c)) error(S);

				break;
		}
	}

	// If scope is created store ref to Node object.
	if (N.value.value === "(") {
		N.brackets.start = N.brackets.end = N.value.start;
		N.brackets.value = N.value.value;
		S.scopes.flag = N;
	}

	validate(S, N);

	if (!isoneliner) {
		N.singleton = true;

		// Add alias node if it exists.
		if (N.alias.value) {
			let cN = node(nk.Flag, S);
			cN.hyphens.value = "-";
			cN.delimiter.value = ",";
			cN.name.value = N.alias.value;
			cN.singleton = true;
			cN.boolean.value = N.boolean.value;
			cN.assignment.value = N.assignment.value;
			cN.alias.value = cN.name.value;
			add(S, cN);

			// Add context node for mutual exclusivity.
			let xN = node(nk.Flag, S);
			xN.value.value = `"{${N.name.value}|${N.alias.value}}"`;
			xN.keyword.value = "context";
			xN.singleton = false;
			xN.virtual = true;
			xN.args.push(xN.value.value);
			add(S, xN);
		}
		add(S, N);
	}

	return N;
};
