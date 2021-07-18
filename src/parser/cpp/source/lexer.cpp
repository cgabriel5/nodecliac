#include "../headers/templates.hpp"
#include "../headers/structs.hpp"

#include <string>
#include <array>
#include <vector>
#include <map>
#include <set>
#include <iostream>
#include <algorithm>
#include <iterator>

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

// [https://stackoverflow.com/a/650307]
enum tkType_Lexer {
	tkSTN,
	tkVAR,
	tkFLG,
	tkCMD,
	tkCMT,
	tkSTR,
	tkTBD,
	tkBRC,
	tkDEF
};

const map<string, tkType_Lexer> sw_lcases {
	{"tkSTN", tkSTN},
	{"tkVAR", tkVAR},
	{"tkFLG", tkFLG},
	{"tkCMD", tkCMD},
	{"tkCMT", tkCMT},
	{"tkSTR", tkSTR},
	{"tkTBD", tkTBD},
	{"tkBRC", tkBRC}
};

map<char, string> SOT { // Start-of-token chars.
	{'#', "tkCMT"},
	{'@', "tkSTN"},
	{'$', "tkVAR"},
	{'-', "tkFLG"},
	{'?', "tkQMK"},
	{'*', "tkMTL"},
	{'.', "tkDDOT"},
	{'"', "tkSTR"},
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
	{'\n', "tkNL"}
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

// [https://stackoverflow.com/a/12333839]
// [https://www.geeksforgeeks.org/set-in-cpp-stl/]
const set<char> SPACES {C_SPACE, C_TAB};
const set<char> tkCMD_TK_TYPES {C_HYPHEN, C_ESCAPE};
const set<char> tkTBD_TK_TYPES {
	C_SPACE, C_TAB, C_DOLLARSIGN, C_ATSIGN,
	C_PIPE, C_LCURLY, C_RCURLY, C_LBRACE,
	C_RBRACE, C_LPAREN, C_RPAREN, C_HYPHEN,
	C_QMARK, C_ASTERISK
	};
const set<char> tkTBD_TK_TYPES2 {C_NL, C_SPACE, C_TAB};
const set<char> tkEOP_TK_TYPES {C_SPACE, C_TAB, C_NL};
const set<string> tkTYPES_RESET1 {"tkCMD", "tkTBD"};
const set<string> tkTYPES_RESET2 {"tkCMD", "tkFLG"};
const set<string> tkTYPES_RESET3 {"tkSTN", "tkVAR"};
const set<string> tkTYPES_RESET4 {"tkCMT", "tkNL", "tkEOP"};

char c = '\0';
map<int, int> dtids;
vector<int> ttids;
vector<Token> tokens;
map<int, string> ttypes;
int token_count = 0;
bool cmdscope = false;
bool valuelist = false; // Value list.
vector<int> brcparens;

// Forward loop x amount.
void forward(State &S, int amount) {
	S.i += amount;
}

// Rollback loop x amount.
void rollback(State &S, int amount) {
	S.i -= amount;
}

// Checks if token is at needed char index.
bool charpos(const State &S, int pos) {
	return S.i - S.start == pos - 1;
}

// Checks state object kind matches provided kind.
bool kind(const State &S, const string &s) {
	return S.kind == s;
}

// Get previous iteration char.
char prevchar(const State &S, const string &text) {
	return text[S.i - 1];
}

void tk_eop(State &S, const char &c, const string &text);

// Adds the token to tokens array.
void add_token(State &S, const string &text) {
	if (!tokens.empty() && !ttids.empty()) {
		Token& prevtk = tokens[ttids.back()];

		// Keyword reset.
		if (kind(S, "tkSTR") && (prevtk.kind == "tkCMD" ||
			(cmdscope && prevtk.kind == "tkTBD"))) {
			int start = prevtk.start;
			int end = prevtk.end;
			if (contains(KEYWORDS, text.substr(start, end - start + 1))) {
				prevtk.kind = "tkKYW";
			}

		// Reset: default $("cmd-string")
		} else if (kind(S, "tkVAR") && S.end - S.start == 0
			&& (prevtk.kind == "tkCMD" || (
			cmdscope && prevtk.kind == "tkTBD"))) {
			int start = prevtk.start;
			int end = prevtk.end;
			if (text.substr(start, end - start + 1) == "default") {
				prevtk.kind = "tkKYW";
			}

		} else if (valuelist && S.kind == "tkFLG" && S.start == S.end) {
			S.kind = "tkFOPT"; // Hyphen.

		// When parsing a value list '--flag=()', that is not a
		// string/command-string should be considered a value.
		} else if (valuelist && contains(tkTYPES_RESET1, S.kind)) {
			S.kind = "tkFVAL";

		// 'Merge' tkTBD tokens if possible.
		} else if ((kind(S, "tkTBD") && prevtk.kind == "tkTBD" &&
				prevtk.line == S.line &&
				S.start - prevtk.end == 1)) {
			prevtk.end = S.end;
			S.kind = "";
			return;

		} else if (kind(S, "tkCMD") || kind(S, "tkTBD")) {
			// Reverse loop to get find first command/flag tokens.
			string lastpassed = "";
			for (int i = token_count - 1; i > 0; i--) {
				auto it = ttypes.find(i);
				string lkind = (it != ttypes.end()) ? it->second : "";
				if (contains(tkTYPES_RESET2, lkind)) {
					lastpassed = lkind;
					break;
				}
			}

			// Handle: 'program = --flag::f=123'
			if ((prevtk.kind == "tkASG" &&
				prevtk.line == S.line &&
				lastpassed == "tkFLG")) {
				S.kind = "tkFVAL";
			}

			if (S.kind != "tkFVAL" && ttids.size() > 1) {
				string prevtk2 = tokens[ttids.end()[-2]].kind;

				// Flag alias '::' reset.
				if (prevtk.kind == "tkDCLN" && prevtk2 == "tkDCLN") {
					S.kind = "tkFLGA";
				}

				// Setting/variable value reset.
				if (prevtk.kind == "tkASG" &&
					contains(tkTYPES_RESET3, prevtk2)) {
					S.kind = "tkAVAL";
				}
			}
		}
	}

	// Reset when single '$'.
	if (kind(S, "tkVAR") && S.end - S.start == 0) {
		S.kind = "tkDLS";
	}

	// If a brace token, reset kind to brace type.
	if (kind(S, "tkBRC")) {
		auto it = BRCTOKENS.find(text[S.start]);
		S.kind = it->second;
	}

	// Universal command multi-char reset.
	if (kind(S, "tkMTL") && (!tokens.size() || tokens.back().kind != "tkASG")) {
		S.kind = "tkCMD";
	}

	ttypes[token_count] = S.kind;
	if (!contains(tkTYPES_RESET4, S.kind)) {
		// Track token ids to help with parsing.
		dtids[token_count] = (token_count && ttids.size()) ? ttids.back() : 0;
		ttids.push_back(token_count);
	}

	Token copy;
	copy.kind = S.kind;
	copy.line = S.line;
	copy.start = S.start;
	copy.end = S.end;
	copy.tid = S.i;

	// Set string line span.
	if (S.lines[0] != -1) {
		copy.lines[0] = S.lines[0];
		copy.lines[1] = S.lines[1];
		S.lines[0] = -1;
		S.lines[1] = -1;
	}

	if (S.last) { S.last = false; }
	copy.tid = token_count;
	tokens.push_back(copy);
	S.kind = "";

	if (S.list) S.list = false;

	token_count += 1;
}

void tk_eop(State &S, const char &c, const string &text) { // Determine in parser.
	S.end = S.i;
	if (contains(tkEOP_TK_TYPES, c)) {
		S.end -= 1;
	}
	add_token(S, text);
}

void tokenizer(const string &text, LexerResponse &LexerData) {
	int l = text.length();

	State S = {};
	S.i = 0;
	S.line = 1;
	S.kind = "";
	S.start = -1;
	S.end = -1;
	S.lines = {-1, -1};
	S.last = false;
	S.list = false;

	while (S.i < l) {
		c = text[S.i];

		// Add 'last' key on last iteration.
		if (S.i == l - 1) { S.last = true; }

		if (S.kind.empty()) {
			if (contains(SPACES, c)) {
				forward(S, 1);
				continue;
			}

			if (c == C_NL) {
				S.line += 1;
				LINESTARTS[S.line] = S.i;
			}

			S.start = S.i;
			auto it = SOT.find(c);
			S.kind = (it != SOT.end()) ? it->second : "tkTBD";
			if (S.kind == "tkTBD") {
				if ((!cmdscope && isalnum(c)) ||
					(cmdscope && !contains(XCSCOPES, c) && isalpha(c))) {
					S.kind = "tkCMD";
				}
			}
		}

		// Tokenization.

		map<string, tkType_Lexer>::const_iterator it;
		it = sw_lcases.find(S.kind);
		switch(it != sw_lcases.end() ? it->second : tkDEF) {
			case tkSTN:
				if (S.i - S.start > 0 && !isalnum(c)) {
					rollback(S, 1);
					S.end = S.i;
					add_token(S, text);
				}

				break;

			case tkVAR:
				if (S.i - S.start > 0 && !(isalnum(c) || c == C_UNDERSCORE)) {
					rollback(S, 1);
					S.end = S.i;
					add_token(S, text);
				}

				break;

			case tkFLG:
				if (S.i - S.start > 0 && !(isalnum(c) || c == C_HYPHEN)) {
					rollback(S, 1);
					S.end = S.i;
					add_token(S, text);
				}

				break;

			case tkCMD:
				if (!(isalnum(c) || contains(tkCMD_TK_TYPES, c) ||
						(prevchar(S, text) == C_ESCAPE))) { // Allow escaped chars.
					rollback(S, 1);
					S.end = S.i;
					add_token(S, text);
				}

				break;

			case tkCMT:
				if (c == C_NL) {
					rollback(S, 1);
					S.end = S.i;
					add_token(S, text);
				}

				break;

			case tkSTR:
				// Store initial line where string starts.
				if (S.lines[0] == -1) {
					S.lines[0] = S.line;
				}

				// Account for '\n's in string to track where string ends
				if (c == C_NL) {
					S.line += 1;
					LINESTARTS[S.line] = S.i;
				}

				if (!charpos(S, 1) && c == text[S.start] &&
						prevchar(S, text) != C_ESCAPE) {
					S.end = S.i;
					S.lines[1] = S.line;
					add_token(S, text);
				}

				break;

			case tkTBD:
				S.end = S.i;
				if (c == C_NL || (contains(tkTBD_TK_TYPES, c) &&
						(prevchar(S, text) != C_ESCAPE))) {
					if (!contains(tkTBD_TK_TYPES2, c)) {
						rollback(S, 1);
						S.end = S.i;
					} else {
						// Let '\n' pass through to increment line count.
						if (c == C_NL) { rollback(S, 1); }
						S.end -= 1;
					}
					add_token(S, text);
				}

				break;

			case tkBRC:
				if (c == C_LPAREN) {
					if (tokens[ttids.back()].kind != "tkDLS") {
						valuelist = true;
						brcparens.push_back(0); // Value list.
						S.list = true;
					} else { brcparens.push_back(1); } // Command-string.
				} else if (c == C_RPAREN) {
					int last_brcparens = brcparens.back();
					brcparens.pop_back();
					if (last_brcparens == 0) {
						valuelist = false;
						S.list = true;
					}
				} else if (c == C_LBRACE) {
					cmdscope = true;
				} else if (c == C_RBRACE) {
					cmdscope = false;
				}
				S.end = S.i;
				add_token(S, text);

				break;

			case tkDEF:
				S.end = S.i;
				add_token(S, text);

				break;

		}

		// Run on last iteration.
		if (S.last) { tk_eop(S, c, text); }

		forward(S, 1);
	}

	// To avoid post parsing checks, add a special end-of-parsing token.
	S.kind = "tkEOP";
	S.start = -1;
	S.end = -1;
	add_token(S, text);

	// [http://cplusplus.bordoon.com/dontforgettoswap.html]
	// [https://stackoverflow.com/a/644693]
	// [https://stackoverflow.com/a/1826373]
	// [https://stackoverflow.com/a/1575369]
	// [https://stackoverflow.com/a/52842140]
	// [https://www.learncpp.com/cpp-tutorial/returning-values-by-value-reference-and-address/]
	LexerData.tokens.swap(tokens);
	LexerData.ttypes.swap(ttypes);
	LexerData.ttids.swap(ttids);
	LexerData.dtids.swap(dtids);
	LexerData.LINESTARTS.swap(LINESTARTS);
}
