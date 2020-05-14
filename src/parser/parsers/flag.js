"use strict";

const node = require("../helpers/nodes.js");
const add = require("../helpers/tree-add.js");
const error = require("../helpers/error.js");
const rollback = require("../helpers/rollback.js");
const validate = require("../helpers/validate.js");
const {
	cin,
	cnotin,
	C_NL,
	C_SPACES,
	C_LETTERS,
	C_QUOTES,
	C_FLG_IDENT
} = require("../helpers/charsets.js");

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
	let end; // Flag: true - ends consuming chars.
	let type = "escaped";
	let N = node(S, "FLAG");

	// If not a oneliner or no command scope, flag is being declared out of scope.
	if (!(isoneliner || S.scopes.command)) error(S, __filename, 10);

	// If flag scope already exists another flag cannot be declared.
	if (S.scopes.flag) error(S, __filename, 11);

	for (; S.i < l; S.i++, S.column++) {
		let char = text.charAt(S.i);

		if (stop || cin(C_NL, char)) {
			N.end = rollback(S) && S.i;
			break; // Stop at nl char.
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
					if (!-~["default", "filedir"].indexOf(keyword)) {
						error(S, __filename);
					}
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
					} else if (char === "=") {
						state = "assignment";
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
					else state = "wsb-prevalue";
					rollback(S);
				}

				break;

			case "pipe-delimiter":
				if (char !== "|") error(S, __filename);
				stop = true;

				break;

			case "wsb-prevalue":
				if (cnotin(C_SPACES, char)) {
					if (char === "|" && N.keyword.value !== "filedir") {
						state = "pipe-delimiter";
					} else state = "value";
					rollback(S);
				}

				break;

			case "value":
				{
					let pchar = text.charAt(S.i - 1);

					if (!N.value.value) {
						// Determine value type.
						if (char === "$") type = "command-flag";
						else if (char === "(") type = "list";
						else if (cin(C_QUOTES, char)) type = "quoted";

						N.value.start = N.value.end = S.i;
						N.value.value = char;
					} else {
						if (
							char === "|" &&
							N.keyword.value !== "filedir" &&
							pchar !== "\\"
						) {
							state = "pipe-delimiter";
							rollback(S);
						} else {
							// If flag is set and chars can still be consumed
							// there is a syntax error. For example, string
							// may be improperly quoted/escaped so error.
							if (end) error(S, __filename);

							let isescaped = pchar !== "\\";
							if (type === "escaped") {
								if (cin(C_SPACES, char) && isescaped)
									end = true;
							} else if (type === "quoted") {
								let vfchar = N.value.value.charAt(0);
								if (char === vfchar && isescaped) end = true;
							}
							N.value.end = S.i;
							N.value.value += char;
						}
					}
				}

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
		add(S, N);
	}

	return N;
};
