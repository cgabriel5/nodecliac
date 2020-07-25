"use strict";

const cin = (set, char) => set.has(char);
const cnotin = (set, char) => !set.has(char);
const create = (...args) => {
	// [https://alligator.io/js/sets-introduction/]
	let r = new Set();

	// Loop over each argument (Set or Array) and build new set.
	for (let i = 0, l = args.length; i < l; i++) {
		let arg = args[i];
		// [https://stackoverflow.com/a/4775737]
		let type = arg.constructor.name;
		if (type === "Set") {
			for (let a of arg) r.add(a);
		} else if (type === "Array") {
			for (let i = 0, l = arg.length; i < l; i++) r.add(arg[i]);
		}
	}

	return r;
};

const C_NL = new Set(["\n", "\r"]);
const C_QUOTES = new Set(['"', "'"]);
const C_SPACES = new Set([" ", "\t"]);
const C_DIGITS = new Set(["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]);
const C_LETTERS = (() => {
	const list = "abcdefghijklmnopqrstuvwxyz".split("");
	let r = new Set(list);
	list.forEach((letter) => r.add(letter.toUpperCase()));
	return r;
})();
const C_SOL = create(C_LETTERS, ["-", "@", ")", "\\", "]", "$", ";", "#", "*"]);
const C_SET_IDENT = create(C_LETTERS, ["-", "_"]);
const C_SET_VALUE = create(C_QUOTES, C_LETTERS, C_DIGITS);
const C_VAR_IDENT = C_SET_IDENT;
const C_VAR_VALUE = C_SET_VALUE;
const C_FLG_IDENT = create(C_LETTERS, C_DIGITS, ["-", "."]);
const C_CMD_IDENT_START = create(C_LETTERS, [":", "*"]);
const C_CMD_IDENT_REM = ["-", "_", ".", ":", "+", "\\"];
const C_CMD_IDENT = create(C_LETTERS, C_DIGITS, C_CMD_IDENT_REM);
const C_CMD_VALUE = new Set(["-", "c", "d", "f", "["]);
const C_KW_ALL = ["context", "default", "filedir", "exclude"];
const C_KD_STR = ["context", "filedir", "exclude"];
const C_CTX_MUT = create(C_LETTERS, C_DIGITS, ["-", "}", "|"]);
const C_CTX_CON = create(C_LETTERS, C_DIGITS, ["#", "-", "!", ","]);
const C_CTX_ALL_CHARS = ["#", "-", "{", "}", "|", "!", ":", ";", ","];
const C_CTX_ALL = create(C_LETTERS, C_DIGITS, C_CTX_ALL_CHARS);
const C_CTX_FLG = create(C_LETTERS, C_DIGITS, ["-", "!", ",", ":"]);
const C_CTX_OPS = new Set(["eq", "ne", "gt", "ge", "lt", "le"]);
const C_CTX_CAT = new Set(["a", "A", "f", "F"]); // Conditional argument-count type.
const C_CTX_CTT = new Set(["c", "C"]); // Conditional test-count type.

module.exports = {
	cin,
	cnotin,
	C_NL,
	C_LETTERS,
	C_QUOTES,
	C_SPACES,
	C_SOL,
	C_SET_IDENT,
	C_SET_VALUE,
	C_VAR_IDENT,
	C_VAR_VALUE,
	C_FLG_IDENT,
	C_CMD_IDENT_START,
	C_CMD_IDENT,
	C_CMD_VALUE,
	C_KW_ALL,
	C_KD_STR,
	C_CTX_MUT,
	C_CTX_CON,
	C_CTX_ALL,
	C_CTX_FLG,
	C_CTX_OPS,
	C_CTX_CAT,
	C_CTX_CTT
};
