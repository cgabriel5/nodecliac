"use strict";

const { hasProp } = require("../../utils/toolbox.js");

const C_NL = { "\n": 1, "\r": 1 };
const C_DIGITS = { 1: 1, 2: 1, 3: 1, 4: 1, 5: 1, 6: 1, 7: 1, 8: 1, 9: 1, 0: 1 };
const C_LETTERS = {
	a: 1,
	b: 1,
	c: 1,
	d: 1,
	e: 1,
	f: 1,
	g: 1,
	h: 1,
	i: 1,
	j: 1,
	k: 1,
	l: 1,
	m: 1,
	n: 1,
	o: 1,
	p: 1,
	q: 1,
	r: 1,
	s: 1,
	t: 1,
	u: 1,
	v: 1,
	w: 1,
	x: 1,
	z: 1,
	y: 1,
	A: 1,
	B: 1,
	C: 1,
	D: 1,
	E: 1,
	F: 1,
	G: 1,
	H: 1,
	I: 1,
	J: 1,
	K: 1,
	L: 1,
	M: 1,
	N: 1,
	O: 1,
	P: 1,
	Q: 1,
	R: 1,
	S: 1,
	T: 1,
	U: 1,
	V: 1,
	W: 1,
	X: 1,
	Z: 1,
	Y: 1
};
const C_QUOTES = { '"': 1, "'": 1 };
const C_SPACES = { " ": 1, "\t": 1 };
const C_SOL = Object.assign({}, C_LETTERS, {
	"-": 1,
	"@": 1,
	")": 1,
	"\\": 1,
	"]": 1,
	$: 1,
	";": 1,
	"#": 1
});
const C_SET_IDENT = Object.assign({}, C_LETTERS, { "-": 1, _: 1 });
const C_SET_VALUE = Object.assign({}, C_QUOTES, C_LETTERS, C_DIGITS);
const C_VAR_IDENT = C_SET_IDENT;
const C_VAR_VALUE = C_SET_VALUE;
const C_FLG_IDENT = Object.assign({}, C_LETTERS, C_DIGITS, {
	"-": 1,
	".": 1
});
const C_CMD_IDENT_START = Object.assign({}, C_LETTERS, { ":": 1 });
const C_CMD_IDENT = Object.assign({}, C_LETTERS, C_DIGITS, {
	"-": 1,
	_: 1,
	".": 1,
	":": 1,
	"+": 1,
	"\\": 1,
	"/": 1
});
const C_CMD_VALUE = { "-": 1, d: 1, "[": 1 };

let cin = (dict, char) => hasProp(dict, char);
let cnotin = (dict, char) => !hasProp(dict, char);

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
	C_CMD_VALUE
};
