"use strict";

const node = require("../helpers/nodes.js");
const add = require("../helpers/tree-add.js");
const error = require("../helpers/error.js");
const rollback = require("../helpers/rollback.js");
const validate = require("../helpers/validate.js");
const bracechecks = require("../helpers/brace-checks.js");
const { r_nl, r_space, r_quote } = require("../helpers/patterns.js");

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
module.exports = S => {
	let { l, text } = S;
	let state = "bullet";
	let end; // Flag: true - ends consuming chars.
	let type = "escaped";
	let N = node(S, "OPTION");

	// Error if flag scope doesn't exist.
	bracechecks(S, null, "pre-existing-fs");

	for (; S.i < l; S.i++, S.column++) {
		let char = text.charAt(S.i);

		if (r_nl.test(char)) {
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
				if (!r_space.test(char)) error(S, __filename);
				state = "wsb-prevalue";

				break;

			case "wsb-prevalue":
				if (!r_space.test(char)) {
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
						else if (r_quote.test(char)) type = "quoted";

						N.value.start = N.value.end = S.i;
						N.value.value = char;
					} else {
						// If flag is set and chars can still be consumed
						// then there is a syntax error. For example, string
						// may be improperly quoted/escaped so error.
						if (end) error(S, __filename);

						let isescaped = pchar !== "\\";
						if (type === "escaped") {
							if (r_space.test(char) && isescaped) end = true;
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
