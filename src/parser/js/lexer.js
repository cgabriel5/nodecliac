#!/usr/bin/env node

"use strict";

const xregexp = require("xregexp");

const C_NL = "\n";
const C_DOT = ".";
const C_TAB = "\t";
const C_PIPE = "|";
const C_SPACE = " ";
const C_QMARK = "?";
const C_HYPHEN = "-";
const C_ESCAPE = "\\";
const C_LPAREN = "(";
const C_RPAREN = ")";
const C_LCURLY = "{";
const C_RCURLY = "}";
const C_LBRACE = "[";
const C_RBRACE = "]";
const C_ATSIGN = "@";
const C_ASTERISK = "*";
const C_DOLLARSIGN = "$";
const C_UNDERSCORE = "_";

const SOT = {
	// Start-of-token chars.
	"#": "tkCMT",
	"@": "tkSTN",
	$: "tkVAR",
	"-": "tkFLG",
	"?": "tkQMK",
	"*": "tkMTL",
	".": "tkDDOT",
	'"': "tkSTR",
	"'": "tkSTR",
	"=": "tkASG",
	"|": "tkDPPE",
	",": "tkDCMA",
	":": "tkDCLN",
	";": "tkTRM",
	"(": "tkBRC",
	")": "tkBRC",
	"[": "tkBRC",
	"]": "tkBRC",
	"{": "tkBRC",
	"}": "tkBRC",
	"\n": "tkNL"
};

const BRCTOKENS = {
	[C_LPAREN]: "tkBRC_LP",
	[C_RPAREN]: "tkBRC_RP",
	[C_LCURLY]: "tkBRC_LC",
	[C_RCURLY]: "tkBRC_RC",
	[C_LBRACE]: "tkBRC_LB",
	[C_RBRACE]: "tkBRC_RB"
};

let LINESTARTS = { 1: -1 };

const KEYWORDS = ["default", "context", "filedir", "exclude"];
// Invalid command start-of-token chars.
const XCSCOPES = [C_ATSIGN, C_DOT, C_LCURLY, C_RCURLY];

// [https://stackoverflow.com/a/12333839]
// [https://www.geeksforgeeks.org/set-in-cpp-stl/]
// const SPACES = new Set([C_SPACE, C_TAB]);
const TkCMD_TK_TYPES = new Set([C_HYPHEN, C_ESCAPE]);
const TkTBD_TK_TYPES = new Set([
	C_SPACE,
	C_TAB,
	C_DOLLARSIGN,
	C_ATSIGN,
	C_PIPE,
	C_LCURLY,
	C_RCURLY,
	C_LBRACE,
	C_RBRACE,
	C_LPAREN,
	C_RPAREN,
	C_HYPHEN,
	C_QMARK,
	C_ASTERISK
]);
const TkTBD_TK_TYPES2 = new Set([C_NL, C_SPACE, C_TAB]);
const TkEOP_TK_TYPES = new Set([C_SPACE, C_TAB, C_NL]);
const TkTYPES_RESET1 = new Set(["tkCMD", "tkTBD"]);
const TkTYPES_RESET2 = new Set(["tkCMD", "tkFLG", "tkSTN", "tkVAR"]);
const TkTYPES_RESET3 = new Set(["tkSTN", "tkVAR"]);
const TkTYPES_RESET4 = new Set(["tkCMT", "tkNL", "tkEOP"]);

// [https://stackoverflow.com/a/31280947]
// [https://dev.to/tillsanders/let-s-stop-using-a-za-z-4a0m]
// [http://www.regular-expressions.info/unicode.html#category]
// [http://www.regular-expressions.info/xregexp.html]
// [http://www.regular-expressions.info/posixbrackets.html]
// [https://ruby-doc.org/core-1.9.3/Regexp.html]
function isalnum(s) {
	if (s === "") return false;
	return xregexp("^[\\p{L}\\p{Nl}\\p{Nd}]+$").test(s);

	// console.log(isalnum("anc"));    // true
	// console.log(isalnum("anc12"));  // true
	// console.log(isalnum("anc12#")); // false
	// console.log(isalnum(""));       // false
}

function isalpha(s) {
	if (s === "") return false;
	return xregexp("^[\\p{L}\\p{Nl}]+$").test(s);

	// console.log(isalpha("abc"));   // true
	// console.log(isalpha("ab123")); // false
	// console.log(isalpha(""));      // false
}

let lastn = (list, offset = -1) => list[list.length + offset];
let strfrmpts = (s, start, end) => s.substring(start, end + 1);

function tokenizer(text) {
	let c = "";
	let dtids = {};
	let ttids = [];
	let tokens = [];
	let ttypes = {};
	let token_count = 0;
	let l = text.length;
	let cmdscope = false;
	let valuelist = false; // Value list.
	let brcparens = [];
	let S = { i: 0, line: 1, kind: "" };
	S.start = S.end = -1;

	// Adds the token to tokens array.
	function add_token(S, text) {
		if (ttids.length && tokens.length) {
			let prevtk = tokens[lastn(ttids)];

			// Keyword reset.
			if (kind(S, "tkSTR") && (prevtk.kind === "tkCMD" || (cmdscope && prevtk.kind === "tkTBD"))) {
				if (KEYWORDS.includes(strfrmpts(text, prevtk.start, prevtk.end))) {
					prevtk.kind = "tkKYW";
				}

				// Reset: default $("cmd-string")
			} else if (
				kind(S, "tkVAR") &&
				S.end - S.start === 0 &&
				(prevtk.kind === "tkCMD" || (cmdscope && prevtk.kind === "tkTBD"))
			) {
				if (strfrmpts(text, prevtk.start, prevtk.end) === "default") {
					prevtk.kind = "tkKYW";
				}
			} else if (valuelist && S.kind === "tkFLG" && S.start === S.end) {
				S.kind = "tkFOPT"; // Hyphen.

				// When parsing a value list '--flag=()', that is not a
				// string/command-string should be considered a value.
			} else if (valuelist && TkTYPES_RESET1.has(S.kind)) {
				S.kind = "tkFVAL";

				// 'Merge' tkTBD tokens if possible.
			} else if (
				kind(S, "tkTBD") &&
				prevtk.kind === "tkTBD" &&
				prevtk.line === S.line &&
				S.start - prevtk.end === 1
			) {
				prevtk.end = S.end;
				S.kind = "";
				return;
			} else if (kind(S, "tkCMD") || kind(S, "tkTBD")) {
				// Reverse loop to get find first command/flag tokens.
				let lastpassed = "";
				// [https://stackoverflow.com/a/19887835]
				for (let i = token_count - 1; i > -1; i--) {
					let lkind = ttypes[i];
					if (TkTYPES_RESET2.has(lkind)) {
						lastpassed = lkind;
						break;
					}
				}

				// Handle: 'program = --flag::f=123'
				if (prevtk.kind === "tkASG" && prevtk.line === S.line && lastpassed === "tkFLG") {
					S.kind = "tkFVAL";
				}

				if (S.kind !== "tkFVAL" && ttids.length > 1) {
					let prevtk2 = tokens[lastn(ttids, -2)].kind;

					// Flag alias '::' reset.
					if (prevtk.kind === "tkDCLN" && prevtk2 === "tkDCLN") {
						S.kind = "tkFLGA";
					}

					// Setting/variable value reset.
					if (prevtk.kind === "tkASG" && TkTYPES_RESET3.has(prevtk2)) {
						S.kind = "tkAVAL";
					}
				}
			}
		}

		// Reset when single '$'.
		if (kind(S, "tkVAR") && S.end - S.start === 0) {
			S.kind = "tkDLS";
		}

		// If a brace token, reset kind to brace type.
		if (kind(S, "tkBRC")) {
			S.kind = BRCTOKENS[text[S.start]];
		}

		// Universal command multi-char reset.
		if (kind(S, "tkMTL") && (!tokens.length || lastn(tokens).kind !== "tkASG")) {
			S.kind = "tkCMD";
		}

		ttypes[token_count] = S.kind;
		if (!TkTYPES_RESET4.has(S.kind)) {
			// Track token ids to help with parsing.
			dtids[token_count] = token_count && ttids.length ? lastn(ttids) : 0;
			ttids.push(token_count);
		}

		let copy = Object.assign({}, S);
		delete copy.i;
		if (S.last) {
			delete S.last;
			delete copy.last;
		}
		copy.tid = token_count;
		tokens.push(copy);

		S.kind = "";

		if (S.lines) delete S.lines;
		if (S.list) delete S.list;

		token_count += 1;
	}

	// Checks if token is at needed char index.
	function charpos(S, pos) {
		return S.i - S.start === pos - 1;
	}

	// Checks state object kind matches provided kind.
	function kind(S, k) {
		return S.kind === k;
	}

	// Forward loop x amount.
	function forward(S, amount) {
		S.i += amount;
	}

	// Rollback loop x amount.
	function rollback(S, amount) {
		S.i -= amount;
	}

	// Get previous iteration char.
	function prevchar(S, text) {
		return text[S.i - 1];
	}

	function tk_eop(S, c, text) {
		// Determine in parser.
		S.kind = "tkEOP";
		S.end = S.i;
		if (TkEOP_TK_TYPES.has(c)) {
			S.end -= 1;
		}
		add_token(S, text);
	}

	while (S.i < l) {
		c = text.charAt(S.i);

		// Add 'last' key on last iteration.
		if (S.i === l - 1) {
			S.last = true;
		}

		if (S.kind === "") {
			if (new Set([C_SPACE, C_TAB]).has(c)) {
				forward(S, 1);
				continue;
			}

			if (c === C_NL) {
				S.line += 1;
				LINESTARTS[S.line] = S.i;
			}

			S.start = S.i;
			S.kind = SOT[c] || "tkTBD";
			if (S.kind === "tkTBD") {
				if ((!cmdscope && isalnum(c)) || (cmdscope && XCSCOPES.includes(c) && isalpha(c))) {
					S.kind = "tkCMD";
				}
			}
		}

		switch (S.kind) {
			case "tkSTN":
				if (S.i - S.start > 0 && !isalnum(c)) {
					rollback(S, 1);
					S.end = S.i;
					add_token(S, text);
				}

				break;

			case "tkVAR":
				if (S.i - S.start > 0 && !(isalnum(c) || c === C_UNDERSCORE)) {
					rollback(S, 1);
					S.end = S.i;
					add_token(S, text);
				}

				break;

			case "tkFLG":
				if (S.i - S.start > 0 && !(isalnum(c) || c === C_HYPHEN)) {
					rollback(S, 1);
					S.end = S.i;
					add_token(S, text);
				}

				break;

			case "tkCMD":
				if (!(isalnum(c) || TkCMD_TK_TYPES.has(c) || prevchar(S, text) === C_ESCAPE)) {
					// Allow escaped chars.
					rollback(S, 1);
					S.end = S.i;
					add_token(S, text);
				}

				break;

			case "tkCMT":
				if (c === C_NL) {
					rollback(S, 1);
					S.end = S.i;
					add_token(S, text);
				}

				break;

			case "tkSTR":
				// Store initial line where string starts.
				// [https://stackoverflow.com/a/18358357]
				if (!S.lines) {
					S.lines = [S.line, -1];
				}

				// Account for '\n's in string to track where string ends
				if (c === C_NL) {
					S.line += 1;
					LINESTARTS[S.line] = S.i;
				}

				if (!charpos(S, 1) && c === text[S.start] && prevchar(S, text) !== C_ESCAPE) {
					S.end = S.i;
					S.lines[1] = S.line;
					add_token(S, text);
				}

				break;

			case "tkTBD":
				S.end = S.i;
				if (c === C_NL || (TkTBD_TK_TYPES.has(c) && prevchar(S, text) !== C_ESCAPE)) {
					if (!TkTBD_TK_TYPES2.has(c)) {
						rollback(S, 1);
						S.end = S.i;
					} else {
						// Let '\n' pass through to increment line count.
						if (c === C_NL) {
							rollback(S, 1);
						}
						S.end -= 1;
					}
					add_token(S, text);
				}

				break;

			case "tkBRC":
				if (c === C_LPAREN) {
					if (tokens[lastn(ttids)].kind !== "tkDLS") {
						valuelist = true;
						brcparens.push(0); // Value list.
						S.list = true;
					} else {
						brcparens.push(1);
					} // Command-string.
				} else if (c === C_RPAREN) {
					if (brcparens.pop() === 0) {
						valuelist = false;
						S.list = true;
					}
				} else if (c === C_LBRACE) {
					cmdscope = true;
				} else if (c === C_RBRACE) {
					cmdscope = false;
				}
				S.end = S.i;
				add_token(S, text);

				break;

			default:
				// tkDEF
				S.end = S.i;
				add_token(S, text);
		}

		// Run on last iteration.
		if (S.last) {
			tk_eop(S, c, text);
		}

		forward(S, 1);
	}

	// To avoid post parsing checks, add a special end-of-parsing token.
	S.kind = "tkEOP";
	S.start = -1;
	S.end = -1;
	add_token(S, text);

	return { tokens, ttypes, ttids, dtids, LINESTARTS };
}

module.exports = { tokenizer };
