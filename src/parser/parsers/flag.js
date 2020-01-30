"use strict";

const node = require("../helpers/nodes.js");
const add = require("../helpers/tree-add.js");
const error = require("../helpers/error.js");
const rollback = require("../helpers/rollback.js");
const validate = require("../helpers/validate.js");
const { r_nl, r_space, r_letter, r_quote } = require("../helpers/patterns.js");

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
	let state = text.charAt(S.i) === "-" ? "hyphen" : "keyword"; // Initial parsing state.
	let stop; // Flag indicating whether to stop parser.
	let end_comsuming;
	let type = "escaped";
	let N = node(S, "FLAG");

	//  If not a oneliner or no command scope, flag is being declared out of scope.
	if (!(isoneliner || S.scopes.command)) error(S, __filename, 10);

	// If flag scope already exists another flag cannot be declared.
	if (S.scopes.flag) error(S, __filename, 11);

	for (; S.i < l; S.i++, S.column++) {
		let char = text.charAt(S.i);

		// Stop on a newline char.
		if (stop || r_nl.test(char)) {
			N.end = rollback(S) && S.i;
			break;
		}

		switch (state) {
			case "hyphen":
				// With RegExp to parse on unescaped '|' characters it would be
				// something like this: String.split(/(?<=[^\\]|^|$)\|/);
				// [https://stackoverflow.com/a/25895905]
				// [https://stackoverflow.com/a/12281034]

				// Only hyphens are allowed at this point.
				if (!N.hyphens.value) {
					// If char is not a hyphen, error.
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
					let keyword = text.substr(S.i, keyword_len);

					// If keyword isn't 'default', error.
					if (keyword !== "default") error(S, __filename);
					N.keyword.start = S.i;
					N.keyword.end = S.i + keyword_len - 1;
					N.keyword.value = keyword;
					state = "keyword-spacer";

					// Note: Forward index to skip keyword chars.
					S.i += keyword_len - 1;
					S.column += keyword_len - 1;
				}

				break;

			case "keyword-spacer":
				// Char must be a ws char, else error.
				if (!r_space.test(char)) error(S, __filename);
				state = "wsb-prevalue";

				break;

			case "name":
				if (!N.name.value) {
					// If char is not a hyphen, error.
					if (!r_letter.test(char)) error(S, __filename);
					N.name.start = N.name.end = S.i;
					N.name.value = char;
				} else {
					if (/[-.a-zA-Z0-9]/.test(char)) {
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
					} else if (r_space.test(char)) {
						state = "wsb-postname";
						rollback(S);
					} else error(S, __filename);
				}

				break;

			case "wsb-postname":
				// Anything but ws, an eq-sign, or '|' is invalid.
				if (!r_space.test(char)) {
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
				// If char is a '*' store info, else go to value state.
				if (char === "*") {
					N.multi.start = N.multi.end = S.i;
					N.multi.value = char;
					state = "wsb-prevalue";
				} else {
					rollback(S);

					// Reset parsing state (based on character).
					if (char === "|") state = "pipe-delimiter";
					else state = "wsb-prevalue";
				}

				break;

			case "pipe-delimiter":
				// Note: Pipe-delimiter serves to delimit individual flag sets.
				// With RegExp to parse on unescaped '|' characters it would be
				// something like this: String.split(/(?<=[^\\]|^|$)\|/);
				// [https://stackoverflow.com/a/25895905]
				// [https://stackoverflow.com/a/12281034]

				if (char !== "|") error(S, __filename);
				stop = true;

				break;

			case "wsb-prevalue":
				// Once a n-ws char is hit, switch state.
				if (!r_space.test(char)) {
					rollback(S);

					// Reset parsing state (based on character).
					if (char === "|") state = "pipe-delimiter";
					else state = "value";
				}

				break;

			case "value":
				{
					let pchar = text.charAt(S.i - 1);

					// Determine value type.
					if (!N.value.value) {
						if (char === "$") type = "command-flag";
						else if (char === "(") type = "list";
						else if (r_quote.test(char)) type = "quoted";

						N.value.start = N.value.end = S.i;
						N.value.value = char;
					} else {
						// Check if character is a delimiter.
						if (char === "|" && pchar !== "\\") {
							state = "pipe-delimiter";
							rollback(S);

							break;
						}

						// If flag is set and chars can still be consumed
						// then there is a syntax error. For example, string
						// may be improperly quoted/escaped so error.
						if (end_comsuming) error(S, __filename);

						if (type === "escaped") {
							if (r_space.test(char) && pchar !== "\\") {
								end_comsuming = true;
							}
						} else if (type === "quoted") {
							let value_fchar = N.value.value.charAt(0);
							if (char === value_fchar && pchar !== "\\") {
								end_comsuming = true;
							}
						}
						N.value.end = S.i;
						N.value.value += char;
					}
				}

				break;
		}
	}

	// If flag starts a scope block, store reference to node object.
	if (N.value.value === "(") {
		N.brackets = {
			start: N.value.start,
			end: N.value.start,
			value: N.value.value
		};

		S.scopes.flag = N; // Store reference to node object.
	}

	validate(S, N);

	if (!isoneliner) {
		add(S, N);
		N.singleton = true;
	}

	return N;
};
