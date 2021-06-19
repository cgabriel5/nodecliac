// from acdef import acdef
// from formatter import formatter
// from issue import Issue

#include "../headers/structs.hpp"
#include "../headers/lexer.hpp"
#include "../headers/parser.hpp"
#include "../headers/validation.hpp"
#include "../headers/defvars.hpp"
#include "../headers/str.hpp"

#include <string>
#include <vector>
#include <set>
#include <regex>
#include <iostream>

using namespace std;

// [https://stackoverflow.com/a/2072890]
inline bool endswith(string const &value, string const &ending) {
	if (ending.size() > value.size()) return false;
	return equal(ending.rbegin(), ending.rend(), value.rbegin());
}

// [https://www.delftstack.com/howto/cpp/how-to-trim-a-string-cpp/]
// [https://stackoverflow.com/a/25385766]
// [https://stackoverflow.com/a/217605]
// [https://stackoverflow.com/a/29892589]
// [https://www.techiedelight.com/trim-string-cpp-remove-leading-trailing-spaces/]
const string WHITE_SPACE_CHARS = " \t\n\r\f\v";
string& ltrim(string &str)  {
	str.erase(0, str.find_first_not_of(WHITE_SPACE_CHARS));
	return str;
}

// string& rtrim(string& str, string& chars) {
string& rtrim(string &str) {
	str.erase(str.find_last_not_of(WHITE_SPACE_CHARS) + 1);
	return str;
}

// string& trim(string& str, string& chars) {
string& trim(string &str) {
	return ltrim(rtrim(str));
}

// [https://stackoverflow.com/a/28097056]
// [https://stackoverflow.com/a/43823704]
// [https://stackoverflow.com/a/1701083]
template <typename T, typename V>
bool contains(T const &container, V const &value) {
	auto it = find(container.begin(), container.end(), value);
	return (it != container.end());
}

template <typename T, typename V>
bool hasKey(T const &map, V const &value) {
	// [https://stackoverflow.com/a/3136545]
	auto it = map.find(value);
	return (it != map.end());
}

// [https://stackoverflow.com/a/23242922]
// [https://www.delftstack.com/howto/cpp/remove-element-from-vector-cpp/]
// [https://iq.opengenus.org/ways-to-remove-elements-from-vector-cpp/]
template<typename T, typename V>
void remove(vector<T> &v, const V &value) {
	v.erase(remove(v.begin(), v.end(), value), v.end());
}

const char C_LF = 'f';
const char C_LT = 't';

const char C_ATSIGN = '@';
const char C_HYPHEN = '-';
const char C_DOLLARSIGN = '$';

const string C_PRIM_TBOOL = "true";
const string C_PRIM_FBOOL = "false";

enum tkType {
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
	//
	tkDCLN,
	tkFLGA,
	tkQMK,
	tkMTL,
	tkFVAL,
	tkDPPE,
	tkBRC_RB,
	//
	tkFOPT,
	tkTBD,
	tkBRC_RP
};

// [https://stackoverflow.com/a/650307]
tkType hashit2 (string const &type) {
	if (type == "tkSTN") return tkSTN;
	if (type == "tkVAR") return tkVAR;
	if (type == "tkCMD") return tkCMD;
	if (type == "tkBRC_LC") return tkBRC_LC;
	if (type == "tkFLG") return tkFLG;
	if (type == "tkBRC_LP") return tkBRC_LP;
	if (type == "tkDLS") return tkDLS;
	if (type == "tkOPTS") return tkOPTS;
	if (type == "tkBRC_LB") return tkBRC_LB;
	if (type == "tkKYW") return tkKYW;

	if (type == "tkASG") return tkASG;
	if (type == "tkSTR") return tkSTR;
	if (type == "tkAVAL") return tkAVAL;
	if (type == "tkDDOT") return tkDDOT;
	if (type == "tkBRC_RC") return tkBRC_RC;

	if (type == "tkDCLN") return tkDCLN;
	if (type == "tkFLGA") return tkFLGA;
	if (type == "tkQMK") return tkQMK;
	if (type == "tkMTL") return tkMTL;
	if (type == "tkFVAL") return tkFVAL;
	if (type == "tkDPPE") return tkDPPE;
	if (type == "tkBRC_RB") return tkBRC_RB;

	if (type == "tkFOPT") return tkFOPT;
	if (type == "tkTBD") return tkTBD;
	if (type == "tkBRC_RP") return tkBRC_RP;

	return tkDCMA;
}

// [https://www.boost.org/users/download/]
// std::string r(R"((?<!\\)\$\{\s*[^}]*\s*\})");
// std::string r(R"((?<=^|[^\\])\$\{\s*[^}]*\s*\})");
// std::string r(R"((?:^|[^\\])\$\{\s*[^}]*\s*\})");
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

vector<int> ubids;
vector<string> excludes;
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

string tkstr(LexerResponse &LexerData, const string &text, const int tid) {
	if (tid == -1) return "";
	if (LexerData.tokens[tid].kind == "tkSTR") {
		if (!LexerData.tokens[tid].$.empty()) return LexerData.tokens[tid].$;
	}
	int start = LexerData.tokens[tid].start;
	int end = LexerData.tokens[tid].end;
	return text.substr(start, end - start);
}

void err(int tid, string message, StateParse &S, LexerResponse &LexerData,
		const string &text, string pos="start", string scope="") {
	// When token ID points to end-of-parsing token,
	// reset the id to the last true token before it.
	if (LexerData.tokens[tid].kind == "tkEOP") tid = LexerData.ttids[-1];

	Token token = LexerData.tokens[tid];
	int line = token.line;
	int index = (pos == "start") ? token.start : token.end;
	// msg = f"{message}";
	int col = index - LexerData.LINESTARTS[line];

	if (endswith(message, ":")) message += " '" + tkstr(LexerData, text, tid) + "'";

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

	// Issue().error(S["filename"], line, col, message);
}

void warn(int tid, string message, StateParse &S, LexerResponse &LexerData,
		const string &text) {
	Token token = LexerData.tokens[tid];
	int line = token.line;
	int index = token.start;
	int col = index - LexerData.LINESTARTS[line];

	if (endswith(message, ":")) message += " '" + tkstr(LexerData, text, tid) + "'";

	if (!hasKey(S.warnings, line)) {
		vector<vector<Warning>> list;
		S.warnings[line] = list;
	}

	Warning warning;
	warning.filename = S.filename;
	warning.line = line;
	warning.column = col;
	warning.message = message;

	vector<Warning> tlist;
	tlist.push_back(warning);
	S.warnings[line].push_back(tlist);
	S.warn_lines.insert(line);
}

void hint(int tid, string message, StateParse &S, LexerResponse &LexerData,
		const string &text) {
	Token token = LexerData.tokens[tid];
	int line = token.line;
	int index = token.start;
	int col = index - LexerData.LINESTARTS[line];

	if (endswith(message, ":")) message += " '" + tkstr(LexerData, text, tid) + "'";

	// Issue().hint(S["filename"], line, col, message)
}

void addtoken(StateParse &S, LexerResponse &LexerData, const int i, const string &text="") {
	// Interpolate/track interpolation indices for string.
	if (LexerData.tokens[i].kind == "tkSTR") {
		string value = tkstr(LexerData, text, i);
		LexerData.tokens[i].$ = value;

		if (!hasKey(vindices, i)) {
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

				// cout << "size: " << it->size() << endl;
				// cout << "expression match #" << 0 << ": " << match[0] << endl;

				// cout << "\nMatched  string is = " << match.str(0)
					// << "\nand it is found at position "
					// << match.position(0) << endl;

				for(int i = 1; i < it->size(); ++i) {
					int start = match.position(1) + 1;
					end_ = start + match[i].length() - 1;
					string varname = match.str(0).substr(3, match.str(0).length() - 4);
					trim(varname);

					if (!hasKey(VARSTABLE, varname)) {
						// Note: Modify token index to point to
						// start of the variable position.
						LexerData.tokens[S.tid].start += start;
						// err(ttid, "Undefined variable", scope="child");
					}

					USED_VARS[varname] = 1;
					vector<int> list {start, end_};
					vindices[i].push_back(list);

					tmpstr += value.substr(pointer, start - pointer);
					auto itv = VARSTABLE.find(varname);
					string sub = (itv != VARSTABLE.end()) ? itv->second : "";

					// Unquote string if quoted.
					tmpstr += (sub[0] != '"' || sub[0] != '\'') ? sub : sub.substr(1, sub.length() - 1);
					pointer = end_;

					// cout << "capture submatch #" << i << ": " << match[i] << endl;
					// cout << "points (" << start << ", " << end_ << ")" << endl;
					// cout << "VARNAME [" << varname << "]" << endl;
					// cout << "Capture " << match.str(1)
					// 	<< " at position " << match.position(1) << endl;
				}
				++it;
			}

			// Get tail-end of string.
			tmpstr += value.substr(end_);
			LexerData.tokens[i].$ = tmpstr;

			if (vindices[i].empty()) { vindices.erase(i); }
		}
	}

	branch.push_back(LexerData.tokens[i]);
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

void addbranch(StateParse &S, LexerResponse &LexerData, const vector<Token> b) {
	BRANCHES.push_back(b);
}

void newbranch() {
	vector<Token> b;
	branch = b;
}

Token prevtoken(StateParse &S, LexerResponse &LexerData) {
	// [https://stackoverflow.com/a/3136545]
	auto it = LexerData.dtids.find(S.tid);
	return LexerData.tokens[it->second];
}

// Command chain/flag grouping helpers.
// ================================

void newgroup() {
	vector<int> c;
	chain = c;
}

void addtoken_group(int i) {
	chain.push_back(i);
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
	vector<int> values {-1};
	flag.values.push_back(values);
}

void setflagprop(const string &prop, const bool &prev_val_group=false) {
	if (prop != "values") {
		if (prop == "tid")             flag.tid =        S.tid;
		else if (prop == "alias")      flag.alias =      S.tid;
		else if (prop == "boolean")    flag.boolean =    S.tid;
		else if (prop == "assignment") flag.assignment = S.tid;
		else if (prop == "multi")      flag.multi =      S.tid;
		else if (prop == "union")      flag.union_ =     S.tid;
	} else {
		if (!prev_val_group) {
			vector<int> list {S.tid};
			flag.values.push_back(list);
		} else {
			flag.values.back().push_back(S.tid);
		}
	}
}

void newflag() {
	Flag flag;
	setflagprop("tid");
	int index = CCHAINS.size() - 1;
	if (!hasKey(FLAGS, index)) {
		vector<Flag> list;
		FLAGS[index] = list;
	}
	FLAGS[index].push_back(flag);
}

// Setting/variable grouping helpers.
// ================================

void newgroup_stn() {
	vector<int> s;
	setting = s;
}

void addtoken_stn_group(const int i) {
	setting.push_back(i);
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
	variable.push_back(i);
}

void addgroup_var(vector<int> &g) {
	VARIABLES.push_back(g);
}

// void addtoprevgroup_var() {
// 	newgroup_var();
// 	VARIABLES.back().push_back(variable);
// }

// ============================

string parser(const string &action, const string &text,
	const string &cmdname, const string &source,
	const tabdata &fmt, const bool &trace,
	const bool &igc, const bool &test) {

	// Add builtin variables to variable table.
	for (auto const &x : builtins(cmdname)) {
		VARSTABLE[x.first] = x.second;
	}

	cout << "INSIDE PARSER FUNCTION" << endl;

	LexerResponse LexerData;
	tokenizer(text, LexerData);

	// cout << "LexerData.tokens-2:" << &LexerData.tokens << endl;

	// [https://stackoverflow.com/a/12702604]
	// [https://stackoverflow.com/a/26282004]
	// cout << LexerData.tokens.size() << endl;
	// for (auto &token : LexerData.tokens) {
	// 	cout << "tid: " << token.tid << endl;
	// 	cout << "kind: " << token.kind << endl;
	// 	cout << "line: " << token.line << endl;
	// 	cout << "start: " << token.start << endl;
	// 	cout << "end: " << token.end << endl;
	// 	cout << "lines: " << token.lines[0] << ", " << token.lines[1] << endl;
	// 	cout << "" << endl;
	// }

	// cout << LexerData.tokens.size() << endl;
	// for (auto &linestart : LexerData.LINESTARTS) {
	// 	cout << "tid: " << token.tid << endl;
	// 	cout << "line: " << linestart.lines[0] << ", " << token.lines[1] << endl;
	// 	cout << "" << endl;
	// }

	// cout << "LexerData.LINESTARTS-2:" << &LexerData.LINESTARTS << endl;

	// // [https://stackoverflow.com/a/26282004]
	// for (auto const &x : LexerData.LINESTARTS) {
	// 	cout << x.first << " : " << x.second << endl;
	// }

	// // [https://stackoverflow.com/a/26282004]
	// for (auto const &x : LexerData.ttypes) {
	// 	cout << x.first << " : " << x.second << endl;
	// }

	// // [https://stackoverflow.com/a/26282004]
	// for (auto const &x : LexerData.dtids) {
	// 	cout << x.first << " : " << x.second << endl;
	// }

	// =========================================================================

	int i = 0;
	int l = LexerData.tokens.size();

	while (i < l) {
		Token token = LexerData.tokens[i];
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
			addtoken(S, LexerData, ttid, text);

			if (SCOPE.empty()) {
				addbranch(S, LexerData, branch);
				newbranch();
				vector<string> list {""};
				expect(list);
			} else {
				if (!NEXT.empty() && !nextany()) {
					// err(ttid, "Improper termination", scope="child");
				}
			}

			i += 1;
			continue;
		}

		if (SCOPE.empty()) {

			if (kind != "tkEOP") {
				addtoken(S, LexerData, ttid, text);
			}

			if (!BRANCHES.empty()) {
				Token ltoken = BRANCHES.back().back(); // Last branch token.
				if (line == ltoken.line && ltoken.kind != "tkTRM") {
					// err(ttid, "Improper termination", scope="parent");
				}
			}

			oneliner = -1;

			if (kind != "tkEOP") {
				if (contains(tkTYPES_1, kind)) {
					addbranch(S, LexerData, branch);
					addscope(kind);
					if (kind == "tkSTN") {
						newgroup_stn();
						addgroup_stn(setting);
						addtoken_stn_group(S.tid);

						vsetting(S, LexerData, text);
						vector<string> list {"", "tkASG"};
						expect(list);
					} else if (kind == "tkVAR") {
						newgroup_var();
						addgroup_var(variable);
						addtoken_var_group(S.tid);

						string varname = tkstr(LexerData, text, S.tid).substr(1);
						VARSTABLE[varname] = "";

						if (!hasKey(USER_VARS, varname)) {
							vector<int> list;
							USER_VARS[varname] = list;
						}
						USER_VARS[varname].push_back(S.tid);

						vvariable(S, LexerData, text);
						vector<string> list {"", "tkASG"};
						expect(list);
					} else if (kind == "tkCMD") {
						addtoken_group(S.tid);
						addgroup(chain);

						vector<string> list {"", "tkDDOT", "tkASG", "tkDCMA"};
						expect(list);

						string command = tkstr(LexerData, text, S.tid);
						if (command != "*" && command != cmdname) {
							// warn(S["tid"], f"Unexpected command:");
						}
					}
				} else {
					if (kind == "tkCMT") {
						addbranch(S, LexerData, branch);
						newbranch();
						vector<string> list {""};
						expect(list);
					} else { // Handle unexpected parent tokens.
						// err(S["tid"], "Unexpected token:", scope="parent");
					}
				}
			}

		} else {

			if (kind == "tkCMT") {
				addtoken(S, LexerData, ttid, text);
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
					// err(S["tid"], "Unexpected token:", scope="child");
				}
			}

			addtoken(S, LexerData, ttid, text);

			// Oneliners must be declared on oneline, else error.
			if (branch[0].kind == "tkCMD" && (
				((hasscope("tkFLG") || hasscope("tkKYW"))
				|| contains(tkTYPES_2, kind))
				&& !hasscope("tkBRC_LB"))) {
				if (oneliner == -1) {
					oneliner = token.line;
				} else if (token.line != oneliner) {
					// err(S["tid"], "Improper oneliner", scope="child")
				}
			}

			switch(hashit2(prevscope())) {
				case tkSTN:
					switch(hashit2(kind)) {
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

							vstring(S, LexerData, text);

							break;
						}
						case tkAVAL: {
							addtoken_stn_group(S.tid);

							vector<string> list {""};
							expect(list);

							vsetting_aval(S, LexerData, text);

							break;
						}
					}

					break;

				case tkVAR:
					switch(hashit2(kind)) {
						case tkASG: {
							addtoken_var_group(S.tid);

							vector<string> list {"tkSTR"};
							expect(list);

							break;
						}
						case tkSTR: {
							addtoken_var_group(S.tid);
							int size = branch.size();
							VARSTABLE[tkstr(LexerData, text, branch[size - 3].tid).substr(1)]
							= tkstr(LexerData, text, S.tid);

							vector<string> list {""};
							expect(list);

							vstring(S, LexerData, text);

							break;
						}
					}

					break;

				case tkCMD:
					switch(hashit2(kind)) {
						case tkASG: {
							// If a universal block, store group id.
							if (hasKey(LexerData.dtids, S.tid)) {
								Token prevtk = prevtoken(S, LexerData);
								if (prevtk.kind == "tkCMD" && text[prevtk.start] == '*') {
									ubids.push_back(CCHAINS.size() - 1);
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
							if (hasKey(LexerData.dtids, S.tid)) {
								Token prevtk = prevtoken(S, LexerData);
								if (prevtk.kind == "tkCMD" && text[prevtk.start] == '*') {
									ubids.push_back(CCHAINS.size() - 1);
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
					switch(hashit2(kind)) {
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
					switch(hashit2(kind)) {
						case tkDCLN: {
							if (prevtoken(S, LexerData).kind != "tkDCLN") {
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

							if (hasscope("tkBRC_LB") && token.line == prevtoken(S, LexerData).line) {
								// err(S.tid, "Flag same line (nth)", scope="child");
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

							if (hasscope("tkBRC_LB") && token.line == prevtoken(S, LexerData).line) {
								// err(S.tid, "Keyword same line (nth)", scope="child");
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
					switch(hashit2(kind)) {
						case tkFOPT: {
							Token prevtk = prevtoken(S, LexerData);
							if (prevtk.kind == "tkBRC_LP") {
								if (prevtk.line == line) {
									// err(S.tid, "Option same line (first)", scope="child");
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

							Token prevtk = prevtoken(S, LexerData);
							if (prevtk.kind == "tkBRC_LP") {
								// warn(prevtk.tid, "Empty scope (flag)");
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
					switch(hashit2(kind)) {
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
					switch(hashit2(kind)) {
						case tkFOPT: {
							if (prevtoken(S, LexerData).line == line) {
								// err(S.tid, "Option same line (nth)", scope="child");
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
					switch(hashit2(kind)) {
						case tkFLG: {
							newflag();

							if (hasscope("tkBRC_LB") && token.line == prevtoken(S, LexerData).line) {
								// err(S["tid"], "Flag same line (first)", scope="child");
							}
							addscope(kind);
							vector<string> list {"tkASG", "tkQMK", "tkDCLN",
								"tkFVAL", "tkDPPE", "tkBRC_RB"};
							expect(list);

							break;
						}
						case tkKYW: {
							newflag();

							if (hasscope("tkBRC_LB") && token.line == prevtoken(S, LexerData).line) {
								// err(S["tid"], "Keyword same line (first)", scope="child");
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

							Token prevtk = prevtoken(S, LexerData);
							if (prevtk.kind == "tkBRC_LB") {
								// warn(prevtk["tid"], "Empty scope (command)");
							}

							break;
						}

					}

					break;

				case tkKYW:
					switch(hashit2(kind)) {
						case tkSTR: {
							setflagprop("values");

							// Collect exclude values for use upstream.
							if (hasKey(LexerData.dtids, S.tid)) {
								Token prevtk = prevtoken(S, LexerData);
								if (prevtk.kind == "tkKYW" and
									tkstr(LexerData, text, prevtk.tid) == "exclude") {
									string exvalues = tkstr(LexerData, text, prevtk.tid);
									exvalues = exvalues.substr(1, exvalues.length() - 1);
									trim(exvalues);
									vector<string> excl_values;
									split(excl_values, exvalues, ";");

									for (auto &exvalue : excl_values) {
										excludes.push_back(exvalue);
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
					switch(hashit2(kind)) {
						case tkCMD: {
							addtoken_group(S.tid);

							popscope();
							vector<string> list {"", "tkDDOT", "tkASG", "tkDCMA"};
							expect(list);

							string command = tkstr(LexerData, text, S.tid);
							if (command != "*" && command != cmdname) {
								// warn(S.tid, f"Unexpected command:");
							}
							break;
						}

					}

					break;

				default:

					int placeholder = 0;
					// err(tokens[S["tid"]]["tid"], f"Unexpected token:", pos="end");

			}
		}

		i += 1;
	}

	// // Check for any unused variables && give warning.
	// for uservar in USER_VARS:
	// 	if uservar not in USED_VARS:
	// 		for tid in USER_VARS[uservar]:
	// 			warn(tid, f"Unused variable: '{uservar}'")
	// 			S["warn_lsort"].add(tokens[tid]["line"])

	// // Sort warning lines && print issues.
	// warnlines = list(S["warn_lines"])
	// warnlines.sort()
	// for warnline in warnlines:
	// 	// Only sort lines where unused variable warning(s) were added.
	// 	if warnline in S["warn_lsort"] && len(S["warnings"][warnline]) > 1:
	// 		// [https://stackoverflow.com/a/4233482]
	// 		S["warnings"][warnline].sort(key = operator.itemgetter(1, 2))
	// 	for warning in S["warnings"][warnline]:
	// 		Issue().warn(*warning)

	// if action == "make": return acdef(BRANCHES, CCHAINS, FLAGS, SETTINGS, S)
	// else: return formatter(tokens, text, BRANCHES, CCHAINS, FLAGS, SETTINGS, S)

	return "";

}
