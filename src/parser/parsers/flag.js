"use strict";

const node = require("../helpers/nodes.js");
const add = require("../helpers/tree-add.js");
const error = require("../helpers/error.js");
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
	let { l, text } = S;
	let state = text.charAt(S.i) === "-" ? "hyphen" : "keyword";
	let stop; // Flag: true - stops parser.
	let type = "escaped";
	let N = node(S, "FLAG");
	let alias = false;
	let qchar = "";
	let comment = false;
	let braces = [];

	// If not a oneliner or no command scope, flag is being declared out of scope.
	if (!(isoneliner || S.scopes.command)) error(S, __filename, 10);

	// If flag scope already exists another flag cannot be declared.
	if (S.scopes.flag) error(S, __filename, 11);

	let char, pchar = "";
	for (; S.i < l; S.i++, S.column++) {
		pchar = char;
		char = text.charAt(S.i);

		if (stop || cin(C_NL, char)) {
			N.end = rollback(S) && S.i;
			break; // Stop at nl char.
		}

		if (char === "#" && pchar !== "\\" && (state !== "value" || comment)) {
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
					if (char !== "-") error(S, __filename);
					N.hyphens.start = N.hyphens.end = S.i;
					N.hyphens.value = char;
				} else {
					if (char !== "-") {
						state = "name";
						rollback(S);
					} else {
						N.hyphens.end = S.i;
						N.hyphens.value += char;
					}
				}

				break;

			case "keyword":
				{
					let keyword_len = 7;
					let endpoint = keyword_len - 1;
					let keyword = text.substr(S.i, keyword_len);

					// Keyword must be allowed.
					if (!-~C_KW_ALL.indexOf(keyword)) error(S, __filename);
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
				if (cnotin(C_SPACES, char)) error(S, __filename);
				state = "wsb-prevalue";

				break;

			case "name":
				if (!N.name.value) {
					if (cnotin(C_LETTERS, char)) error(S, __filename);
					N.name.start = N.name.end = S.i;
					N.name.value = char;
				} else {
					if (cin(C_FLG_IDENT, char)) {
						N.name.end = S.i;
						N.name.value += char;
					} else if (char === ":" && !alias) {
						state = "alias";
						rollback(S);
					} else if (char === "=") {
						state = "assignment";
						rollback(S);
					} else if (char === ",") {
						state = "delimiter";
						rollback(S);
					} else if (char === "?") {
						state = "boolean-indicator";
						rollback(S);
					} else if (char === "|") {
						state = "pipe-delimiter";
						rollback(S);
					} else if (cin(C_SPACES, char)) {
						state = "wsb-postname";
						rollback(S);
					} else error(S, __filename);
				}

				break;

			case "wsb-postname":
				if (cnotin(C_SPACES, char)) {
					if (char === "=") {
						state = "assignment";
						rollback(S);
					} else if (char === ",") {
						state = "delimiter";
						rollback(S);
					} else if (char === "|") {
						state = "pipe-delimiter";
						rollback(S);
					} else error(S, __filename);
				}

				break;

			case "boolean-indicator":
				N.boolean.start = N.boolean.end = S.i;
				N.boolean.value = char;
				state = "pipe-delimiter";

				break;

			case "alias":
				alias = true;
				// Next char must also be a colon.
				let nchar = text.charAt(S.i + 1);
				if (nchar !== ":") error(S, __filename);
				N.alias.start = S.i;
				N.alias.end = S.i + 2;

				let letter = text.charAt(S.i + 2);
				if (cnotin(C_LETTERS, letter)) {
					S.i += 1;
					S.column += 1;
					error(S, __filename);
				}

				N.alias.value = letter;
				state = "name";

				// Note: Forward indices to skip alias chars.
				S.i += 2;
				S.column += 2;

				break;

			case "assignment":
				N.assignment.start = N.assignment.end = S.i;
				N.assignment.value = char;
				state = "multi-indicator";

				break;

			case "multi-indicator":
				if (char === "*") {
					N.multi.start = N.multi.end = S.i;
					N.multi.value = char;
					state = "wsb-prevalue";
				} else {
					if (char === "|") state = "pipe-delimiter";
					else if (char === ",") state = "delimiter";
					else state = "wsb-prevalue";
					rollback(S);
				}

				break;

			case "pipe-delimiter":
				// Note: If char is not a pipe or if the flag is not a oneliner
				// flag and there are more characters after the flag error.
				// Example:
				// * = [
				// 		--help?|context "!help: #fge1"
				// ]
				if (char !== "|" || !isoneliner) error(S, __filename);
				stop = true;

				break;

			case "delimiter":
				N.delimiter.start = N.delimiter.end = S.i;
				N.delimiter.value = char;
				state = "eol-wsb";

				break;

			case "wsb-prevalue":
				if (cnotin(C_SPACES, char)) {
					let keyword = !-~C_KD_STR.indexOf(N.keyword.value);
					if (char === "|" && keyword) state = "pipe-delimiter";
					else if (char === ",") state = "delimiter";
					else state = "value";
					rollback(S);
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
						if (
							char === "|" &&
							!-~C_KD_STR.indexOf(N.keyword.value) &&
							pchar !== "\\"
						) {
							state = "pipe-delimiter";
							rollback(S);
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
										if (
											N.value.value.length === 1 &&
											char !== "("
										) {
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
												error(S, __filename);
											}
											braces.pop();
											if (!braces.length) {
												state = "eol-wsb";
											}
										}

										if (cin(C_QUOTES, char)) {
											if (!qchar) qchar = char;
											else if (qchar === char) qchar = "";
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
				}

				break;

			case "eol-wsb":
				if (
					char === "|" &&
					!-~C_KD_STR.indexOf(N.keyword.value) &&
					pchar !== "\\"
				) {
					state = "pipe-delimiter";
					rollback(S);
				} else if (cnotin(C_SPACES, char)) error(S, __filename);

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
			let cN = node(S, "FLAG");
			cN.hyphens.value = "-";
			cN.delimiter.value = ",";
			cN.name.value = N.alias.value;
			cN.singleton = true;
			cN.boolean.value = N.boolean.value;
			cN.assignment.value = N.assignment.value;
			cN.alias.value = cN.name.value;
			add(S, cN);
		}
		add(S, N);
	}

	return N;
};
