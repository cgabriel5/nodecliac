const { customs, defaults } = require("./data.json");
const lcp = require("../../lcp.js");

const options = {
	charloop_startindex: 2,
	min_frqz_prefix_len: 2,
	min_prefix_len: 3,
	min_frqz_count: 3,
	char_break_points: ["="],
	prepend: "--",
	append: "..."
};

console.log("\nCustoms:");
for (let i = 0, l = customs.length; i < l; i++) {
	let res = lcp(customs[i], options).prefixes;
	console.log(i + 1, res.length, res);
}

console.log("\nDefaults:");
for (let i = 0, l = defaults.length; i < l; i++) {
	let res = lcp(defaults[i]).prefixes;
	console.log(i + 1, res.length, res);
}
