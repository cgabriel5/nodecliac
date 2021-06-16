#include <string>
#include <array>
#include <vector>
#include <map>
#include <set>
#include <iostream>
#include <algorithm>

using namespace std;

const char C_NL = '\n';
const char C_DOT = '.';
const char C_TAB = '\t';
const char C_PIPE = '|';
const char C_SPACE = ' ';
const char C_QMARK = '?';
const char C_HYPHEN = '-';
const char C_ESCAPE = '\\';
const char C_LPAREN = '(';
const char C_RPAREN = ')';
const char C_LCURLY = '{';
const char C_RCURLY = '}';
const char C_LBRACE = '[';
const char C_RBRACE = ']';
const char C_ATSIGN = '@';
const char C_ASTERISK = '*';
const char C_DOLLARSIGN = '$';
const char C_UNDERSCORE = '_';

map<char, string> SOT { // Start-of-token chars.
	{'#', "tkCMT"},
	{'@', "tkSTN"},
	{'$', "tkVAR"},
	{'-', "tkFLG"},
	{'?', "tkQMK"},
	{'*', "tkMTL"},
	{'.', "tkDDOT"},
	{'a', "tkSTR"},
	{'\'', "tkSTR"},
	{'=', "tkASG"},
	{'|', "tkDPPE"},
	{',', "tkDCMA"},
	{':', "tkDCLN"},
	{';', "tkTRM"},
	{'(', "tkBRC"},
	{')', "tkBRC"},
	{'[', "tkBRC"},
	{']', "tkBRC"},
	{'{', "tkBRC"},
	{'}', "tkBRC"},
	{'\\', "tkNL"}
};

map<char, string> BRCTOKENS {
	{C_LPAREN, "tkBRC_LP"},
	{C_RPAREN, "tkBRC_RP"},
	{C_LCURLY, "tkBRC_LC"},
	{C_RCURLY, "tkBRC_RC"},
	{C_LBRACE, "tkBRC_LB"},
	{C_RBRACE, "tkBRC_RB"}
};

map<int, int> LINESTARTS { {1, -1} };

array<string, 4> KEYWORDS = {"default", "context", "filedir", "exclude"};
// Invalid command start-of-token chars.
array<char, 4> XCSCOPES = {C_ATSIGN, C_DOT, C_LCURLY, C_RCURLY};

struct State {
	int i, line, start, end;
	string kind;
	bool last;
};

// Forward loop x amount.
void forward(State &S, int amount) {
	S.i += amount;
}

// [https://stackoverflow.com/a/28097056]
// [https://stackoverflow.com/a/43823704]
template <typename T, typename V>
bool contains(T const &container, V const &value) {
	auto it = find(container.begin(), container.end(), value);
	return (it != container.end());
}

template <typename T, typename V>
bool hasKey(T const &map, V const &value) {
	// [https://stackoverflow.com/a/3136545]
	auto iter = map.find(value);
	return (iter != map.end());
}


void tokenizer(const string &text) {
	char c = '\0';
	map<int, int> dtids;
	vector<int> ttids;
	// tokens = []
	// ttypes = {}
	int token_count = 0;
	int l = text.length();
	bool cmdscope = false;
	bool valuelist = false; // Value list.
	// brcparens = []

	State S = {};
	S.i = 0;
	S.line = 1;
	S.kind = "";
	S.start = -1;
	S.end = -1;

	// // Adds the token to tokens array.
	// def add_token():
	// 	nonlocal token_count, ttypes

	// 	if tokens and ttids:
	// 		prevtk = tokens[ttids[-1]]

	// 		// Keyword reset.
	// 		if (kind("tkSTR") and (prevtk["kind"] == "tkCMD" or
	// 			(cmdscope and prevtk["kind"] == "tkTBD"))):
	// 			if (text[prevtk["start"]:prevtk["end"] + 1]
	// 					in KEYWORDS):
	// 				prevtk["kind"] = "tkKYW"

	// 		// Reset: default $("cmd-string")
	// 		elif (kind("tkVAR") and S.end - S.start == 0
	// 			and (prevtk["kind"] == "tkCMD" or (
	// 			cmdscope and prevtk["kind"] == "tkTBD"))):
	// 			if text[prevtk["start"]:prevtk["end"] + 1] == "default":
	// 				prevtk["kind"] = "tkKYW"

	// 		elif valuelist and S.kind == "tkFLG" and S.start == S.end:
	// 			S.kind = "tkFOPT" // Hyphen.

	// 		// When parsing a value list '--flag=()', that is not a
	// 		// string/commang-string should be considered a value.
	// 		elif valuelist and S.kind in ("tkCMD", "tkTBD"):
	// 			S.kind = "tkFVAL"

	// 		// 'Merge' tkTBD tokens if possible.
	// 		elif (kind("tkTBD") and prevtk["kind"] == "tkTBD" and
	// 			  prevtk["line"] == S.line and
	// 			  S.start - prevtk["end"] == 1):
	// 			prevtk["end"] = S.end
	// 			S.kind = ""
	// 			return

	// 		elif kind("tkCMD") or kind("tkTBD"):
	// 			// Reverse loop to get find first command/flag tokens.
	// 			lastpassed = ""
	// 			for i in range(token_count - 1, -1, -1):
	// 				lkind = ttypes[i]
	// 				if lkind in ("tkCMD", "tkFLG"):
	// 					lastpassed = lkind
	// 					break

	// 			// Handle: 'program = --flag::f=123'
	// 			if (prevtk["kind"] == "tkASG" and
	// 				prevtk["line"] == S.line and
	// 				lastpassed == "tkFLG"):
	// 				S.kind = "tkFVAL"

	// 			if S.kind != "tkFVAL" and len(ttids) > 1:
	// 				prevtk2 = tokens[ttids[-2]]["kind"]

	// 				// Flag alias '::' reset.
	// 				if (prevtk["kind"] == "tkDCLN" and prevtk2 == "tkDCLN"):
	// 					S.kind = "tkFLGA"

	// 				// Setting/variable value reset.
	// 				if prevtk["kind"] == "tkASG" and prevtk2 in ("tkSTN", "tkVAR"):
	// 					S.kind = "tkAVAL"

	// 	// Reset when single '$'.
	// 	if kind("tkVAR") and S.end - S.start == 0:
	// 		S.kind = "tkDLS"

	// 	// If a brace token, reset kind to brace type.
	// 	if kind("tkBRC"): S.kind = BRCTOKENS.get(text[S.start])

	// 	// Universal command multi-char reset.
	// 	if kind("tkMTL") and (not tokens or tokens[-1]["kind"] != "tkASG"):
	// 		S.kind = "tkCMD"

	// 	ttypes[token_count] = S.kind
	// 	if S.kind not in ("tkCMT", "tkNL", "tkEOP"):
	// 		// Track token ids to help with parsing.
	// 		dtids[token_count] = ttids[-1] if token_count and ttids else 0
	// 		ttids.append(token_count)

	// 	copy = dict(S)
	// 	del copy["i"]
	// 	if S.get("last", False):
	// 		del S.last
	// 		del copy["last"]
	// 	copy["tid"] = token_count
	// 	tokens.append(copy)
	// 	S.kind = ""

	// 	if S.get("lines", False):
	// 		del S.lines

	// 	if S.get("list", False):
	// 		del S.list

	// 	token_count += 1

	// // Checks if token is at needed char index.
	// def charpos(pos):
	// 	return S.i - S.start == pos - 1

	// // Checks state object kind matches provided kind.
	// def kind(s):
	// 	return S.kind == s

	// // Forward loop x amount.
	// void forward(int amount) {
	// 	S.i += amount;
	// }

	// // Rollback loop x amount.
	// def rollback(amount):
	// 	S.i -= amount

	// // Get previous iteration char.
	// def prevchar():
	// 	return text[S.i - 1]

	// // Tokenizer loop functions.

	// def tk_stn():
	// 	if S.i - S.start > 0 and not (c.isalnum()):
	// 		rollback(1)
	// 		S.end = S.i
	// 		add_token()

	// def tk_var():
	// 	if S.i - S.start > 0 and not (c.isalnum() or c == C_UNDERSCORE):
	// 		rollback(1)
	// 		S.end = S.i
	// 		add_token()

	// def tk_flg():
	// 	if S.i - S.start > 0 and not (c.isalnum() or c == C_HYPHEN):
	// 		rollback(1)
	// 		S.end = S.i
	// 		add_token()

	// def tk_cmd():
	// 	if not (c.isalnum() or c in (C_HYPHEN, C_ESCAPE) or
	// 			(prevchar() == C_ESCAPE)):  // Allow escaped chars.
	// 		rollback(1)
	// 		S.end = S.i
	// 		add_token()

	// def tk_cmt():
	// 	if c == C_NL:
	// 		rollback(1)
	// 		S.end = S.i
	// 		add_token()

	// def tk_str():
	// 	// Store initial line where string starts.
	// 	if "lines" not in S:
	// 		S.lines = [S.line, -1]

	// 	// Account for '\n's in string to track where string ends
	// 	if c == C_NL:
	// 		S.line += 1

	// 		LINESTARTS.setdefault(S.line, S.i);

	// 	if (not charpos(1) and c == text[S.start] and
	// 			prevchar() != C_ESCAPE):
	// 		S.end = S.i
	// 		S.lines[1] = S.line
	// 		add_token()

	// def tk_tbd():  // Determine in parser.
	// 	S.end = S.i
	// 	if c == C_NL or (c in (
	// 			C_SPACE, C_TAB, C_DOLLARSIGN, C_ATSIGN,
	// 			C_PIPE, C_LCURLY, C_RCURLY, C_LBRACE,
	// 			C_RBRACE, C_LPAREN, C_RPAREN, C_HYPHEN,
	// 			C_QMARK, C_ASTERISK
	// 		) and (prevchar() != C_ESCAPE)):
	// 		if c not in (C_NL, C_SPACE, C_TAB):
	// 			rollback(1)
	// 			S.end = S.i
	// 		else:
	// 			// Let '\n' pass through to increment line count.
	// 			if c == C_NL: rollback(1)
	// 			S.end -= 1
	// 		add_token()

	// def tk_brc():
	// 	nonlocal cmdscope, valuelist, brcparens  // [https://stackoverflow.com/a/8448011]
	// 	if c == C_LPAREN:
	// 		if tokens[ttids[-1]]["kind"] != "tkDLS":
	// 			valuelist = True
	// 			brcparens.append(0) // Value list.
	// 			S.list = True
	// 		else: brcparens.append(1) // Command-string.
	// 	elif c == C_RPAREN:
	// 		if brcparens.pop() == 0:
	// 			valuelist = False
	// 			S.list = True
	// 	elif c == C_LBRACE: cmdscope = True
	// 	elif c == C_RBRACE: cmdscope = False
	// 	S.end = S.i
	// 	add_token()

	// def tk_def():
	// 	S.end = S.i
	// 	add_token()

	// def tk_eop():  // Determine in parser.
	// 	S.end = S.i
	// 	if c in (C_SPACE, C_TAB, C_NL):
	// 		S.end -= 1
	// 	add_token()

	// DISPATCH = {
	// 	"tkSTN": tk_stn,
	// 	"tkVAR": tk_var,
	// 	"tkFLG": tk_flg,
	// 	"tkCMD": tk_cmd,
	// 	"tkCMT": tk_cmt,
	// 	"tkSTR": tk_str,
	// 	"tkTBD": tk_tbd,
	// 	"tkBRC": tk_brc,
	// 	"tkDEF": tk_def
	// }

	// [https://stackoverflow.com/a/12333839]
	// [https://www.geeksforgeeks.org/set-in-cpp-stl/]
	const set<char> SPACES {C_SPACE, C_TAB};

	while (S.i < l) {
		c = text[S.i];

		// cout << "i: " << S.i << " = [" << c << "]" << endl;

		// Add 'last' key on last iteration.
		if (S.i == l - 1) S.last = true;

		if (S.kind.empty()) {
			if (SPACES.count(c)) {
				forward(S, 1);
				continue;
			}

			if (c == C_NL) {
				S.line += 1;
				LINESTARTS[S.line] = S.i;
			}

			S.start = S.i;
			// [https://stackoverflow.com/a/3136545]
			auto it = SOT.find(c);
			S.kind = (it != SOT.end()) ? it->second : "tkTBD";
			if (S.kind == "tkTBD") {
				if ((!cmdscope && isalnum(c)) ||
					(cmdscope && !contains(XCSCOPES, c) && isalpha(c))) {
					S.kind = "tkCMD";
				}
			}
		}

		// DISPATCH.get(S.kind, tk_def)()

		// // Run on last iteration.
		// if S.get("last", False): tk_eop()

		forward(S, 1);
	}

	// To avoid post parsing checks, add a special end-of-parsing token.
	S.kind = "tkEOP";
	S.start = -1;
	S.end = -1;
	// add_token();


	// [https://stackoverflow.com/a/26282004]
	// for (auto const &x : LINESTARTS) {
	// 	cout << x.first << " : " << x.second << endl;
	// }

	// return (tokens, ttypes, ttids, dtids)
}
