"use strict";

/**
 * Formats template string (?) with provided values.
 *
 * @param {string} template - Template string to use.
 * @param {any} data - Objects are merged other types are string casted.
 * @return {string} - The formatted template string.
 */
const fmt = function(template, ...args) {
	let rmap = {};

	for (let i = 0, l = args.length; i < l; i++) {
		let arg = args[i]; // Cache current loop item.
		if (typeof arg !== "object") rmap[i] = arg;
		else {
			rmap[i] = ""; // Add empty entry to map.
			rmap = Object.assign(rmap, arg);
		}
	}

	let count = 0;
	return template.replace(/(?<!\\)\?(\d+|[-a-zA-Z]+)?/g, function(match) {
		match = match.slice(1); // Remove `?` placeholder identifier.
		let res = String(rmap[match || count] || undefined);
		count++;
		return res;
	});
};

// // Usage:
// let obj = { name: "John", 1: "27", 2: "December", 3: "3rd" }; // Data.
// // Template strings.
// let str1 = fmt("My name is ?name and I am ?1 years on ? the ?.", obj);
// let str2 = fmt("My name is ?name and I am ?6 years on ? the ?.", obj, "SECOND");
// console.log(str1);
// console.log(str2);

/**
 * Wrapper for template literal tags.
 *
 * @param  {array} rstrings - The JS provided array of parsed raw strings.
 * @param  {...[array]} values - The array of placeholder values.
 * @return {string} - The formatted template string.
 *
 * @resource [https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Template_literals]
 * @resource [https://wesbos.com/tagged-template-literals/]
 * @resource [https://wesbos.com/tagged-template-literals/]
 * @resource [https://codeburst.io/javascript-es6-tagged-template-literals-a45c26e54761]
 */
let rtp = (rstrings, ...values) => {
	let res = "";

	for (let i = 0, l = rstrings.length; i < l; i++) {
		let rstring = rstrings[i]; // Cache current loop item.
		// Weave in the value after the raw string.
		res += rstring + (values[i] || "");
	}

	return res;
};

// // Usage:
// let obj = { name: "John", 1: "27", 2: "December", 3: "3rd" }; // Data.
// let name = obj.name;
// let farg = obj[1];
// let sarg = obj[2];
// let targ = obj[3];
// let str = rtp`My name is ${name} and I am ${farg} years on ${sarg} the ${targ}.`;
// console.log(str);

module.exports = { fmt, rtp };
