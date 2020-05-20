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
	let end; // Flag: true - ends consuming chars.
	let type = "escaped";
	let N = node(S, "OPTION");

	// Error if flag scope doesn't exist.
	bracechecks(S, null, "pre-existing-fs");

	for (; S.i < l; S.i++, S.column++) {
		let char = text.charAt(S.i);

		if (cin(C_NL, char)) {
			N.end = rollback(S) && S.i;
			break; // Stop at nl char.
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
					let pchar = text.charAt(S.i - 1);

					if (!N.value.value) {
						// Determine value type.
						if (char === "$") type = "command-flag";
						else if (char === "(") type = "list";
						else if (cin(C_QUOTES, char)) type = "quoted";

						N.value.start = N.value.end = S.i;
						N.value.value = char;
					} else {
						// If flag is set and chars can still be consumed
						// then there is a syntax error. For example, string
						// may be improperly quoted/escaped so error.
						if (end) error(S, __filename);

						let isescaped = pchar !== "\\";
						if (type === "escaped") {
							if (cin(C_SPACES, char) && isescaped) end = true;
						} else if (type === "quoted") {
							let vfchar = N.value.value.charAt(0);
							if (char === vfchar && isescaped) end = true;
						}
						N.value.end = S.i;
						N.value.value += char;
					}
				}

				break;
		}
	}

	validate(S, N);
	add(S, N);
};
