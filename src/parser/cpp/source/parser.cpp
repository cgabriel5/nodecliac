#include "../headers/templates.hpp"
#include "../headers/structs.hpp"
#include "../headers/acdef.hpp"
#include "../headers/formatter.hpp"
#include "../headers/lexer.hpp"
#include "../headers/parser.hpp"
#include "../headers/validation.hpp"
#include "../headers/issue.hpp"
#include "../headers/defvars.hpp"
#include "../headers/str.hpp"
#include "../headers/parsetools.hpp"

#include <tuple>
#include <string>
#include <vector>
#include <set>
#include <regex>
#include <iostream>
#include <algorithm>

using namespace std;

// const char C_LF = 'f';
// const char C_LT = 't';

// const char C_ATSIGN = '@';
// const char C_HYPHEN = '-';
// const char C_DOLLARSIGN = '$';

// const string C_PRIM_TBOOL = "true";
// const string C_PRIM_FBOOL = "false";

enum tkType_Parser {
	tkSTN,
	tkVAR,
	tkCMD,
	tkBRC_LC,
	tkFLG,
	tkBRC_LP,
	tkDLS,
	tkOPTS,
	tkBRC_LB,
	tkKYW,
	tkDCMA,
	//
	tkASG,
	tkSTR,
	tkAVAL,
	tkDDOT,
	tkBRC_RC,
	tkDCLN,
	tkFLGA,
	tkQMK,
	tkMTL,
	tkFVAL,
	tkDPPE,
	tkBRC_RB,
	tkFOPT,
	tkTBD,
	tkBRC_RP,
	tkDEF
};

const map<string, tkType_Parser> sw_pcases {
	{"tkSTN", tkSTN},
	{"tkVAR", tkVAR},
	{"tkCMD", tkCMD},
	{"tkBRC_LC", tkBRC_LC},
	{"tkFLG", tkFLG},
	{"tkBRC_LP", tkBRC_LP},
	{"tkDLS", tkDLS},
	{"tkOPTS", tkOPTS},
	{"tkBRC_LB", tkBRC_LB},
	{"tkKYW", tkKYW},
	{"tkDCMA", tkDCMA},
	//
	{"tkASG", tkASG},
	{"tkSTR", tkSTR},
	{"tkAVAL", tkAVAL},
	{"tkDDOT", tkDDOT},
	{"tkBRC_RC", tkBRC_RC},
	{"tkDCLN", tkDCLN},
	{"tkFLGA", tkFLGA},
	{"tkQMK", tkQMK},
	{"tkMTL", tkMTL},
	{"tkFVAL", tkFVAL},
	{"tkDPPE", tkDPPE},
	{"tkBRC_RB", tkBRC_RB},
	{"tkFOPT", tkFOPT},
	{"tkTBD", tkTBD},
	{"tkBRC_RP", tkBRC_RP}
};

// [https://stackoverflow.com/a/650307]
tkType_Parser enumval(string const &type) {
	map<string, tkType_Parser>::const_iterator it = sw_pcases.find(type);
	return (it != sw_pcases.end()) ? it->second : tkDEF;
}

// [https://www.boost.org/users/download/]
std::string re(R"((^|[^\\])(\$\{\s*[^}]*\s*\}))");
std::regex r(re);

// [https://www.mygreatlearning.com/blog/set-in-cpp/]
// [https://stackoverflow.com/a/12333839]
const set<string> tkTYPES_1 {"tkSTN", "tkVAR", "tkCMD"};
const set<string> tkTYPES_2 {"tkFLG", "tkKYW"};
const set<string> tkTYPES_3 {"tkFLG", "tkKYW"};

StateParse S;

int ttid = 0;
vector<string> NEXT;
vector<string> SCOPE;
vector<Token> branch;
vector<vector<Token>> BRANCHES;
int oneliner = -1;

vector<int> chain;
vector<vector<vector<int>>> CCHAINS;

map<int, vector<Flag>> FLAGS;
Flag flag;

vector<int> setting;
vector<vector<int>> SETTINGS;

vector<int> variable;
vector<vector<int>> VARIABLES;

map<string, int> USED_VARS;
map<string, vector<int>> USER_VARS;
map<string, string> VARSTABLE; // = builtins(cmdname)
map<int, vector<vector<int>>> vindices;

void err(StateParse &S, int tid, string message, string pos="start", string scope="") {
	// When token ID points to end-of-parsing token,
	// reset the id to the last true token before it.
	if (S.LexerData.tokens[tid].kind == "tkEOP") tid = S.LexerData.ttids[-1];

	Token& token = S.LexerData.tokens[tid];
	int line = token.line;
	int index = (pos == "start") ? token.start : token.end;
	// msg = f"{message}";
	int col = index - S.LexerData.LINESTARTS[line];

	if (endswith(message, ":")) message += " '" + tkstr(S, tid) + "'";

	// Add token debug information.
	// dbeugmsg = "\n\n\033[1mToken\033[0m: "
	// dbeugmsg += "\n - tid: " + str(token["tid"])
	// dbeugmsg += "\n - kind: " + token["kind"]
	// dbeugmsg += "\n - line: " + str(token["line"])
	// dbeugmsg += "\n - start: " + str(token["start"])
	// dbeugmsg += "\n - end: " + str(token["end"])
	// dbeugmsg += "\n __val__: [" + tkstr(tid) + "]"

	// dbeugmsg += "\n\n\033[1mExpected\033[0m: "
	// for n in NEXT:
	//     if not n: n = "\"\""
	//     dbeugmsg += "\n - " + n
	// dbeugmsg += "\n\n\033[1mScopes\033[0m: "
	// for s in SCOPE:
	//     dbeugmsg += "\n - " + s
	// decor = "-" * 15
	// msg += "\n\n" + decor + " TOKEN_DEBUG_INFO " + decor
	// msg += dbeugmsg
	// msg += "\n\n" + decor + " TOKEN_DEBUG_INFO " + decor

	issue_error(S.filename, line, col, message);
}

void warn(StateParse &S, int tid, string message) {
	Token& token = S.LexerData.tokens[tid];
	int line = token.line;
	int index = token.start;
	int col = index - S.LexerData.LINESTARTS[line];

	if (endswith(message, ":")) message += " '" + tkstr(S, tid) + "'";

	if (!hasKey(S.warnings, line)) {
		vector<Warning> list;
		S.warnings[line] = list;
	}

	Warning warning;
	warning.filename = S.filename;
	warning.line = line;
	warning.column = col;
	warning.message = message;

	S.warnings[line].push_back(warning);
	S.warn_lines.insert(line);
}

void hint(StateParse &S, int tid, string message) {
	Token& token = S.LexerData.tokens[tid];
	int line = token.line;
	int index = token.start;
	int col = index - S.LexerData.LINESTARTS[line];

	if (endswith(message, ":")) message += " '" + tkstr(S, tid) + "'";

	issue_hint(S.filename, line, col, message);
}

void addtoken(StateParse &S, const int i) {
	// Interpolate/track interpolation indices for string.
	if (S.LexerData.tokens[i].kind == "tkSTR") {
		string value = tkstr(S, i);
		S.LexerData.tokens[i].$ = value;

		if (S.args.action != "format" && !hasKey(vindices, i)) {
			int end_ = 0;
			int pointer = 0;
			string tmpstr = "";

			vector<vector<int>> vindice_data;
			vindices[i] = vindice_data;

			// [https://stackoverflow.com/a/32553718]
			// [https://www.geeksforgeeks.org/program-to-find-all-match-of-a-regex-in-a-string/]
			sregex_iterator it(value.begin(), value.end(), r);
			sregex_iterator end;
			while(it != end) {
				smatch match;
				match = *it;

				// +1 to avoid first captured character.
				int start = match.position(1) + 1;
				end_ = start + match[2].length();
				string rawmatch = (*it)[2]; // match.str(0).substr(3, match.str(0).length() - 4);
				string varname = rawmatch.substr(2, rawmatch.length()-3);
				trim(varname);

				if (!hasKey(VARSTABLE, varname)) {
					// Note: Modify token index to point to
					// start of the variable position.
					S.LexerData.tokens[S.tid].start += start;
					err(S, ttid, "Undefined variable", "start", "child");
				}

				USED_VARS[varname] = 1;
				vector<int> list {start, end_};
				vindices[i].push_back(list);

				tmpstr += value.substr(pointer, start - pointer);
				auto itv = VARSTABLE.find(varname);
				string sub = (itv != VARSTABLE.end()) ? itv->second : "";

				// Unquote string if quoted.
				if (!(sub[0] == '"' || sub[0] == '\'')) {
					tmpstr += sub;
				} else {
					tmpstr += sub.substr(1, sub.length() - 2);
				}
				pointer = end_;

				++it;
			}

			// Get tail-end of string.
			tmpstr += value.substr(end_);
			S.LexerData.tokens[i].$ = tmpstr;

			if (vindices[i].empty()) { vindices.erase(i); }
		}
	}

	BRANCHES.back().push_back(S.LexerData.tokens[i]);
}

void expect(vector<string> &list) {
	NEXT.clear();
	NEXT.swap(list);
}

void clearscope() {
	SCOPE.clear();
}

void addscope(const string s) {
	SCOPE.push_back(s);
}

void popscope(int pops=1) {
	while (pops) {
		SCOPE.pop_back();
		pops -= 1;
	}
}

bool hasscope(const string s) {
	return contains(SCOPE, s);
}

string prevscope() {
	return SCOPE.back();
}

bool hasnext(const string s) {
	return contains(NEXT, s);
}

bool nextany() {
	return NEXT[0] == "";
}

void addbranch() {
	BRANCHES.push_back(branch);
}

void newbranch() {
	vector<Token> b;
	branch = b;
}

Token& prevtoken(StateParse &S) {
	// [https://stackoverflow.com/a/3136545]
	auto it = S.LexerData.dtids.find(S.tid);
	return S.LexerData.tokens[it->second];
}

// Command chain/flag grouping helpers.
// ================================

void newgroup() {
	vector<int> c;
	chain = c;
}

void addtoken_group(int i) {
	CCHAINS.back().back().push_back(i);
}

void addgroup(vector<int> &g) {
	vector<vector<int>> g_;
	g_.push_back(g);
	CCHAINS.push_back(g_);
}

void addtoprevgroup() {
	newgroup();
	CCHAINS.back().push_back(chain);
}

// ============================

void newvaluegroup(const string &prop) {
	int index = CCHAINS.size() - 1;
	vector<int> values {-1};
	FLAGS[index].back().values.push_back(values);
}

void setflagprop(const string &prop, const bool &prev_val_group=false) {
	int index = CCHAINS.size() - 1;

	if (prop != "values") {
		if (prop == "tid")             FLAGS[index].back().tid =        S.tid;
		else if (prop == "alias")      FLAGS[index].back().alias =      S.tid;
		else if (prop == "boolean")    FLAGS[index].back().boolean =    S.tid;
		else if (prop == "assignment") FLAGS[index].back().assignment = S.tid;
		else if (prop == "multi")      FLAGS[index].back().multi =      S.tid;
		else if (prop == "union")      FLAGS[index].back().union_ =     S.tid;
	} else {
		if (!prev_val_group) {
			vector<int> list {S.tid};
			FLAGS[index].back().values.push_back(list);
		} else {
			FLAGS[index].back().values.back().push_back(S.tid);
		}
	}
}

void newflag() {
	Flag flag;
	int index = CCHAINS.size() - 1;
	if (!hasKey(FLAGS, index)) {
		vector<Flag> list;
		FLAGS[index] = list;
	}
	FLAGS[index].push_back(flag);
	setflagprop("tid");
}

// Setting/variable grouping helpers.
// ================================

void newgroup_stn() {
	vector<int> s;
	setting = s;
}

void addtoken_stn_group(const int i) {
	SETTINGS.back().push_back(i);
}

void addgroup_stn(vector<int> &g) {
	SETTINGS.push_back(g);
}

// void addtoprevgroup_stn() {
// 	newgroup_stn();
// 	SETTINGS.back().push_back(setting);
// }

// ============================

void newgroup_var() {
	vector<int> v;
	variable = v;
}

void addtoken_var_group(const int i) {
	VARIABLES.back().push_back(i);
}

void addgroup_var(vector<int> &g) {
	VARIABLES.push_back(g);
}

// void addtoprevgroup_var() {
// 	newgroup_var();
// 	VARIABLES.back().push_back(variable);
// }

// ============================

// [https://stackoverflow.com/a/873725]
// [https://stackoverflow.com/a/4892699]
// [https://stackoverflow.com/a/26295515]
bool cmp(const Warning &a, const Warning &b) {
	return a.column < b.column;
}

// ============================

tuple <string, string, string, string, string, string, map<string, string>, string>
	parser(const string &action, string &text,
	const string &cmdname, const string &source,
	const tabdata &fmt, const bool &trace,
	const bool &igc, const bool &test) {

	S.text.swap(text);
	S.filename = source;
	S.args.action = action;
	S.args.source = source;
	S.args.fmt = fmt;
	S.args.trace = trace;
	S.args.igc = igc;
	S.args.test = test;

	// Add builtin variables to variable table.
	for (auto const &x : builtins(cmdname)) {
		VARSTABLE[x.first] = x.second;
	}

	tokenizer(S.text, S.LexerData);

	// =========================================================================

	int i = 0;
	int l = S.LexerData.tokens.size();

	while (i < l) {
		Token& token = S.LexerData.tokens[i];
		string kind = token.kind;
		int line = token.line;
		int start = token.start;
		int end = token.end;
		S.tid = token.tid;

		if (kind == "tkNL") {
			i += 1;
			continue;
		}

		if (kind != "tkEOP") {
			ttid = i;
		}

		if (kind == "tkTRM") {
			if (SCOPE.empty()) {
				addbranch();
				addtoken(S, ttid);
				newbranch();
				vector<string> list {""};
				expect(list);
			} else {
				addtoken(S, ttid);

				if (!NEXT.empty() && !nextany()) {
					err(S, ttid, "Improper termination", "start", "child");
				}
			}

			i += 1;
			continue;
		}

		if (SCOPE.empty()) {

			oneliner = -1;

			if (!BRANCHES.empty()) {
				Token& ltoken = BRANCHES.back().back(); // Last branch token.
				if (line == ltoken.line && ltoken.kind != "tkTRM") {
					err(S, ttid, "Improper termination", "start", "parent");
				}
			}

			if (kind != "tkEOP") {
				addbranch();
				addtoken(S, ttid);
			}

			if (kind != "tkEOP") {
				if (contains(tkTYPES_1, kind)) {
					addscope(kind);
					if (kind == "tkSTN") {
						newgroup_stn();
						addgroup_stn(setting);
						addtoken_stn_group(S.tid);

						vsetting(S);
						vector<string> list {"", "tkASG"};
						expect(list);
					} else if (kind == "tkVAR") {
						newgroup_var();
						addgroup_var(variable);
						addtoken_var_group(S.tid);

						string varname = tkstr(S, S.tid).substr(1);
						VARSTABLE[varname] = "";

						if (!hasKey(USER_VARS, varname)) {
							vector<int> list;
							USER_VARS[varname] = list;
						}
						USER_VARS[varname].push_back(S.tid);

						vvariable(S);
						vector<string> list {"", "tkASG"};
						expect(list);
					} else if (kind == "tkCMD") {
						addgroup(chain);
						addtoken_group(S.tid);

						vector<string> list {"", "tkDDOT", "tkASG", "tkDCMA"};
						expect(list);

						string command = tkstr(S, S.tid);
						if (command != "*" && command != cmdname) {
							warn(S, S.tid, "Unexpected command:");
						}
					}
				} else {
					if (kind == "tkCMT") {
						newbranch();
						vector<string> list {""};
						expect(list);
					} else { // Handle unexpected parent tokens.
						err(S, S.tid, "Unexpected token:", "start", "parent");
					}
				}
			}

		} else {

			if (kind == "tkCMT") {
				addtoken(S, ttid);
				i += 1;
				continue;
			}

			// Remove/add necessary tokens when parsing long flag form.
			if (hasscope("tkBRC_LB")) {
				if (hasnext("tkDPPE")) {
					// [https://iq.opengenus.org/ways-to-remove-elements-from-vector-cpp/]
					// [https://www.delftstack.com/howto/cpp/remove-element-from-vector-cpp/]
					remove(NEXT, "tkDPPE");
					NEXT.push_back("tkFLG");
					NEXT.push_back("tkKYW");
					NEXT.push_back("tkBRC_RB");
				}
			}

			if (!NEXT.empty() && !hasnext(kind)) {
				if (nextany()) {
					clearscope();
					newbranch();

					newgroup();
					continue;

				} else {
					err(S, S.tid, "Unexpected token:", "start", "child");
				}
			}

			addtoken(S, ttid);

			// Oneliners must be declared on oneline, else error.
			if (BRANCHES.back()[0].kind == "tkCMD" && (
				((hasscope("tkFLG") || hasscope("tkKYW"))
				|| contains(tkTYPES_2, kind))
				&& !hasscope("tkBRC_LB"))) {
				if (oneliner == -1) {
					oneliner = token.line;
				} else if (token.line != oneliner) {
					err(S, S.tid, "Improper oneliner", "start", "child");
				}
			}

			switch(enumval(prevscope())) {
				case tkSTN:
					switch(enumval(kind)) {
						case tkASG: {
							addtoken_stn_group(S.tid);

							vector<string> list {"tkSTR", "tkAVAL"};
							expect(list);

							break;
						}
						case tkSTR: {
							addtoken_stn_group(S.tid);

							vector<string> list {""};
							expect(list);

							vstring(S);

							break;
						}
						case tkAVAL: {
							addtoken_stn_group(S.tid);

							vector<string> list {""};
							expect(list);

							vsetting_aval(S);

							break;
						}
					}

					break;

				case tkVAR:
					switch(enumval(kind)) {
						case tkASG: {
							addtoken_var_group(S.tid);

							vector<string> list {"tkSTR"};
							expect(list);

							break;
						}
						case tkSTR: {
							addtoken_var_group(S.tid);
							int size = BRANCHES.back().size();
							VARSTABLE[tkstr(S, BRANCHES.back()[size - 3].tid).substr(1)]
							= tkstr(S, S.tid);

							vector<string> list {""};
							expect(list);

							vstring(S);

							break;
						}
					}

					break;

				case tkCMD:
					switch(enumval(kind)) {
						case tkASG: {
							// If a universal block, store group id.
							if (hasKey(S.LexerData.dtids, S.tid)) {
								Token& prevtk = prevtoken(S);
								if (prevtk.kind == "tkCMD" && S.text[prevtk.start] == '*') {
									S.ubids.push_back(CCHAINS.size() - 1);
								}
							}
							vector<string> list {"tkBRC_LB", "tkFLG", "tkKYW"};
							expect(list);

							break;
						}
						case tkBRC_LB: {
							addscope(kind);
							vector<string> list {"tkFLG", "tkKYW", "tkBRC_RB"};
							expect(list);

							break;
						}
						// // [TODO] Pathway needed?
						// case tkBRC_RB: {
						// 	vector<string> list {"", "tkCMD"};
						// 	expect(list);
						//
						// 	break;
						// }
						case tkFLG: {
							newflag();

							addscope(kind);
							vector<string> list {"", "tkASG", "tkQMK", "tkDCLN",
								"tkFVAL", "tkDPPE", "tkBRC_RB"};
							expect(list);

							break;
						}
						case tkKYW: {
							newflag();

							addscope(kind);
							vector<string> list {"tkSTR", "tkDLS"};
							expect(list);

							break;
						}
						case tkDDOT: {
							vector<string> list {"tkCMD", "tkBRC_LC"};
							expect(list);

							break;
						}
						case tkCMD: {
							addtoken_group(S.tid);

							vector<string> list {"", "tkDDOT", "tkASG", "tkDCMA"};
							expect(list);

							break;
						}
						case tkBRC_LC: {
							addtoken_group(-1);

							addscope(kind);
							vector<string> list {"tkCMD"};
							expect(list);

							break;
						}
						case tkDCMA: {
							// If a universal block, store group id.
							if (hasKey(S.LexerData.dtids, S.tid)) {
								Token& prevtk = prevtoken(S);
								if (prevtk.kind == "tkCMD" && S.text[prevtk.start] == '*') {
									S.ubids.push_back(CCHAINS.size() - 1);
								}
							}
							addtoprevgroup();

							addscope(kind);
							vector<string> list {"tkCMD"};
							expect(list);

							break;
						}
					}

					break;

				case tkBRC_LC:
					switch(enumval(kind)) {
						case tkCMD: {
							addtoken_group(S.tid);

							vector<string> list {"tkDCMA", "tkBRC_RC"};
							expect(list);

							break;
						}
						case tkDCMA: {
							vector<string> list {"tkCMD"};
							expect(list);

							break;
						}
						case tkBRC_RC: {
							addtoken_group(-1);

							popscope();
							vector<string> list {"", "tkDDOT", "tkASG", "tkDCMA"};
							expect(list);

							break;
						}
					}

					break;

				case tkFLG:
					switch(enumval(kind)) {
						case tkDCLN: {
							if (prevtoken(S).kind != "tkDCLN") {
								vector<string> list {"tkDCLN"};
								expect(list);
							} else {
								vector<string> list {"tkFLGA"};
								expect(list);
							}

							break;
						}
						case tkFLGA: {
							setflagprop("alias");

							vector<string> list {"", "tkASG", "tkQMK", "tkDPPE"};
							expect(list);

							break;
						}
						case tkQMK: {
							setflagprop("boolean");

							vector<string> list {"", "tkDPPE"};
							expect(list);

							break;
						}
						case tkASG: {
							setflagprop("assignment");

							vector<string> list {"", "tkDCMA", "tkMTL", "tkDPPE", "tkBRC_LP",
								"tkFVAL", "tkSTR", "tkDLS", "tkBRC_RB"};
							expect(list);

							break;
						}
						case tkDCMA: {
							setflagprop("union");

							vector<string> list {"tkFLG", "tkKYW"};
							expect(list);

							break;
						}
						case tkMTL: {
							setflagprop("multi");

							vector<string> list {"", "tkBRC_LP", "tkDPPE"};
							expect(list);

							break;
						}
						case tkDLS: {
							addscope(kind); // Build cmd-string.
							vector<string> list {"tkBRC_LP"};
							expect(list);

							break;
						}
						case tkBRC_LP: {
							addscope(kind);
							vector<string> list {"tkFVAL", "tkSTR", "tkFOPT", "tkDLS", "tkBRC_RP"};
							expect(list);

							break;
						}
						case tkFLG: {
							newflag();

							if (hasscope("tkBRC_LB") && token.line == prevtoken(S).line) {
								err(S, S.tid, "Flag same line (nth)", "start", "child");
							}
							vector<string> list {"", "tkASG", "tkQMK",
								"tkDCLN", "tkFVAL", "tkDPPE"};
							expect(list);

							break;
						}
						case tkKYW: {
							newflag();

							// [TODO] Investigate why leaving flag scope doesn't affect
							// parsing. For now remove it to keep scopes array clean.
							popscope();

							if (hasscope("tkBRC_LB") && token.line == prevtoken(S).line) {
								err(S, S.tid, "Keyword same line (nth)", "start", "child");
							}
							addscope(kind);
							vector<string> list {"tkSTR", "tkDLS"};
							expect(list);

							break;
						}
						case tkSTR: {
							setflagprop("values");

							vector<string> list {"", "tkDPPE"};
							expect(list);

							break;
						}
						case tkFVAL: {
							setflagprop("values");

							vector<string> list {"", "tkDPPE"};
							expect(list);

							break;
						}
						case tkDPPE: {
							vector<string> list {"tkFLG", "tkKYW"};
							expect(list);

							break;
						}
						case tkBRC_RB: {
							popscope();
							vector<string> list {""};
							expect(list);

							break;
						}

					}

					break;

				case tkBRC_LP:
					switch(enumval(kind)) {
						case tkFOPT: {
							Token& prevtk = prevtoken(S);
							if (prevtk.kind == "tkBRC_LP") {
								if (prevtk.line == line) {
									err(S, S.tid, "Option same line (first)", "start", "child");
								}
								addscope("tkOPTS");
								vector<string> list {"tkFVAL", "tkSTR", "tkDLS"};
								expect(list);
							}

							break;
						}
						case tkFVAL: {
							setflagprop("values");

							vector<string> list {"tkFVAL", "tkSTR", "tkDLS", "tkBRC_RP", "tkTBD"};
							expect(list);

							break;
						}
						// // Disable pathway for now.
						// case tkTBD: {
						// 	setflagprop("values");

						// 	vector<string> list {"tkFVAL", "tkSTR", "tkDLS", "tkBRC_RP", "tkTBD"};
						// 	expect(list);

						// 	break;
						// }
						case tkSTR: {
							setflagprop("values");

							vector<string> list {"tkFVAL", "tkSTR", "tkDLS", "tkBRC_RP", "tkTBD"};
							expect(list);

							break;
						}
						case tkDLS: {
							addscope(kind);
							vector<string> list {"tkBRC_LP"};
							expect(list);

							break;
						}
						// // [TODO] Pathway needed?
						// case tkDCMA: {
						// 	vector<string> list {"tkFVAL", "tkSTR"};
						// 	expect(list);

						// 	break;
						// }
						case tkBRC_RP: {
							popscope();
							vector<string> list {"", "tkDPPE"};
							expect(list);

							Token& prevtk = prevtoken(S);
							if (prevtk.kind == "tkBRC_LP") {
								warn(S, prevtk.tid, "Empty scope (flag)");
							}

							break;
						}
						// // [TODO] Pathway needed?
						// case tkBRC_RB: {
						// 	popscope();
						// 	vector<string> list {""};
						// 	expect(list);

						// 	break;
						// }
					}

					break;

				case tkDLS:
					switch(enumval(kind)) {
						case tkBRC_LP: {
							newvaluegroup("values");
							setflagprop("values", true);

							vector<string> list {"tkSTR"};
							expect(list);

							break;
						}
						case tkDLS: {
							vector<string> list {"tkSTR"};
							expect(list);

							break;
						}
						case tkSTR: {
							vector<string> list {"tkDCMA", "tkBRC_RP"};
							expect(list);

							break;
						}
						case tkDCMA: {
							vector<string> list {"tkSTR", "tkDLS"};
							expect(list);

							break;
						}
						case tkBRC_RP: {
							popscope();

							setflagprop("values", true);

							// Handle: 'program = --flag=$("cmd")'
							// Handle: 'program = default $("cmd")'
							if (contains(tkTYPES_3, prevscope())) {
								if (hasscope("tkBRC_LB")) {
									popscope();
									vector<string> list {"tkFLG", "tkKYW", "tkBRC_RB"};
									expect(list);
								} else {
									// Handle: oneliner command-string
									// 'program = --flag|default $("cmd", $"c", "c")'
									// 'program = --flag::f=(1 3)|default $("cmd")|--flag'
									// 'program = --flag::f=(1 3)|default $("cmd")|--flag'
									// 'program = default $("cmd")|--flag::f=(1 3)'
									// 'program = default $("cmd")|--flag::f=(1 3)|default $("cmd")'
									vector<string> list {"", "tkDPPE", "tkFLG", "tkKYW"};
									expect(list);
								}

							// Handle: 'program = --flag=(1 2 3 $("c") 4)'
							} else if (prevscope() == "tkBRC_LP") {
								vector<string> list {"tkFVAL", "tkSTR", "tkFOPT", "tkDLS", "tkBRC_RP"};
								expect(list);

							// Handle: long-form
							// 'program = [
							// 	--flag=(
							// 		- 1
							// 		- $("cmd")
							// 		- true
							// 	)
							// ]'
							} else if (prevscope() == "tkOPTS") {
								vector<string> list {"tkFOPT", "tkBRC_RP"};
								expect(list);
							}

							break;
						}
					}

					break;

				case tkOPTS:
					switch(enumval(kind)) {
						case tkFOPT: {
							if (prevtoken(S).line == line) {
								err(S, S.tid, "Option same line (nth)", "start", "child");
							}
							vector<string> list {"tkFVAL", "tkSTR", "tkDLS"};
							expect(list);

							break;
						}
						case tkDLS: {
							addscope("tkDLS"); // Build cmd-string.
							vector<string> list {"tkBRC_LP"};
							expect(list);

							break;
						}
						case tkFVAL: {
							setflagprop("values");

							vector<string> list {"tkFOPT", "tkBRC_RP"};
							expect(list);

							break;
						}
						case tkSTR: {
							setflagprop("values");

							vector<string> list {"tkFOPT", "tkBRC_RP"};
							expect(list);

							break;
						}
						case tkBRC_RP: {
							popscope(2);
							vector<string> list {"tkFLG", "tkKYW", "tkBRC_RB"};
							expect(list);

							break;
						}
					}

					break;

				case tkBRC_LB:
					switch(enumval(kind)) {
						case tkFLG: {
							newflag();

							if (hasscope("tkBRC_LB") && token.line == prevtoken(S).line) {
								err(S, S.tid, "Flag same line (first)", "start", "child");
							}
							addscope(kind);
							vector<string> list {"tkASG", "tkQMK", "tkDCLN",
								"tkFVAL", "tkDPPE", "tkBRC_RB"};
							expect(list);

							break;
						}
						case tkKYW: {
							newflag();

							if (hasscope("tkBRC_LB") && token.line == prevtoken(S).line) {
								err(S, S.tid, "Keyword same line (first)", "start", "child");
							}
							addscope(kind);
							vector<string> list {"tkSTR", "tkDLS", "tkBRC_RB"};
							expect(list);

							break;
						}
						case tkBRC_RB: {
							popscope();
							vector<string> list {""};
							expect(list);

							Token& prevtk = prevtoken(S);
							if (prevtk.kind == "tkBRC_LB") {
								warn(S, prevtk.tid, "Empty scope (command)");
							}

							break;
						}

					}

					break;

				case tkKYW:
					switch(enumval(kind)) {
						case tkSTR: {
							setflagprop("values");

							// Collect exclude values for use upstream.
							if (hasKey(S.LexerData.dtids, S.tid)) {
								Token& prevtk = prevtoken(S);
								if (prevtk.kind == "tkKYW" &&
									tkstr(S, prevtk.tid) == "exclude") {
									string exvalues = tkstr(S, prevtk.tid);
									exvalues = exvalues.substr(1, exvalues.length() - 2);
									trim(exvalues);
									vector<string> excl_values;
									split(excl_values, exvalues, ";");

									for (auto &exvalue : excl_values) {
										S.excludes.push_back(exvalue);
									}
								}
							}

							// [TODO] This pathway re-uses the flag (tkFLG) token
							// pathways. If the keyword syntax were to change
							// this will need to change as it might no loner work.
							popscope();
							addscope("tkFLG"); // Re-use flag pathways for now.
							vector<string> list {"", "tkDPPE"};
							expect(list);

							break;
						}
						case tkDLS: {
							addscope(kind); // Build cmd-string.
							vector<string> list {"tkBRC_LP"};
							expect(list);

							break;
						}
						// // [TODO] Pathway needed?
						// case tkBRC_RB: {
						// 	popscope();
						// 	vector<string> list {""};
						// 	expect(list);

						// 	break;
						// }
						// // [TODO] Pathway needed?
						// case tkFLG: {
						// 	vector<string> list {"tkASG", "tkQMK",
						// 		"tkDCLN", "tkFVAL", "tkDPPE"};
						// 	expect(list);

						// 	break;
						// }
						// // [TODO] Pathway needed?
						// case tkKYW: {
						// 	addscope(kind);
						// 	vector<string> list {"tkSTR", "tkDLS"};
						// 	expect(list);

						// 	break;
						// }
						case tkDPPE: {
							// [TODO] Because the flag (tkFLG) token pathways are
							// reused for the keyword (tkKYW) pathways, the scope
							// needs to be removed. This is fine for now but when
							// the keyword token pathway change, the keyword
							// pathways will need to be fleshed out in the future.
							if (prevscope() == "tkKYW") {
								popscope();
								addscope("tkFLG"); // Re-use flag pathways for now.
							}
							vector<string> list {"tkFLG", "tkKYW"};
							expect(list);
							break;
						}

					}

					break;

				case tkDCMA:
					switch(enumval(kind)) {
						case tkCMD: {
							addtoken_group(S.tid);

							popscope();
							vector<string> list {"", "tkDDOT", "tkASG", "tkDCMA"};
							expect(list);

							string command = tkstr(S, S.tid);
							if (command != "*" && command != cmdname) {
								warn(S, S.tid, "Unexpected command:");
							}
							break;
						}

					}

					break;

				default:
					err(S, S.LexerData.tokens[S.tid].tid, "Unexpected token:", "end");

			}
		}

		i += 1;
	}

	// Check for any unused variables && give warning.
	for (auto const &x : USER_VARS) {
		if (!hasKey(USED_VARS, x.first)) {
			for (auto const &tid : USER_VARS[x.first]) {
				warn(S, tid, "Unused variable: '" + x.first + "'");
				S.warn_lsort.insert(S.LexerData.tokens[tid].line);
			}
		}
	}

	// Print issues.
	for (auto const &warnline : S.warn_lines) {
		// Only sort lines where unused variable warning(s) were added.
		vector<Warning>& warnings = S.warnings[warnline];
		if (hasKey(S.warn_lsort, warnline) && warnings.size() > 1) {
			sort(warnings.begin(), warnings.end(), cmp);
		}

		for (auto const &warning : warnings) {
			string filename = warning.filename;
			int line = warning.line;
			int col = warning.column;
			string message = warning.message;

			issue_warn(filename, line, col, message);
		}
	}

	tuple <string, string, string, string, string, string, map<string, string>, string> data;

	if (action == "make") {
		data = acdef(S, BRANCHES, CCHAINS, FLAGS, SETTINGS, cmdname);
	} else {
		data = formatter(S, BRANCHES, CCHAINS, FLAGS, SETTINGS);
	}

	return data;

}
