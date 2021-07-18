"use-strict";

/**
 * Creates an enum object from the provided values.
 *
 * @param  {array} values - The enum values.
 * @return {object} - The created enum object.
 *
 * @resource [https://masteringjs.io/tutorials/fundamentals/enum]
 */
function enums(values) {
	let enums = {};
	for (let val of values) enums[val] = val;
	return Object.freeze(enums);
}

const nk = enums([
	"Comment",
	"Newline",
	"Setting",
	"Variable",
	"Command",
	"Flag",
	"Option",
	"Brace"
]);

module.exports = { enums, nk };
