#include "../headers/templates.hpp"
#include "../headers/structs.hpp"
#include "../headers/str.hpp"
#include "../headers/parsetools.hpp"

#include <tuple>
#include <string>
#include <vector>
#include <map>
#include <set>
#include <regex>
#include <iostream>

using namespace std;

string indent(const string &type_, const int &count,
	const char &ichar, const int &iamount,
	map<string, int> &MXP) {
	// [https://stackoverflow.com/a/167810]
	return std::string(((count || MXP[type_]) * iamount), ichar);
}

int prevtoken(StateParse &S, const int &tid, set<string> &skip/*={"tkNL"}*/) {
	for (int ttid = tid - 1; ttid > -1; ttid--) {
        if (!contains(skip, S.LexerData.tokens[ttid].kind)) {
            return ttid;
        }
    }
    return -1;
}

tuple <string, string, string, string, string, string, map<string, string>, string>
	formatter(StateParse &S,
	vector<vector<Token>> &branches,
	vector<vector<vector<int>>> &cchains,
	map<int, vector<Flag>> &flags,
	vector<vector<int>> &settings) {

    tabdata fmt = S.args.fmt;
    bool igc = S.args.igc;

    // vector<string> output;
    // regex r("^[ \\t]+");

	vector<Token> &tokens = S.LexerData.tokens;
	map<int, string> &ttypes = S.LexerData.ttypes;
	vector<int> &ttids = S.LexerData.ttids;
	map<int, int> &dtids = S.LexerData.dtids;

    // Indentation level multipliers.
    map<string, int> MXP {
        {"tkCMT", 0},
        {"tkCMD", 0},
        {"tkFLG", 1},
        {"tkFOPT", 2},
        {"tkBRC", 0},
        {"tkNL", 0},
        {"tkSTN", 0},
        {"tkVAR", 0},
        {"tkBRC_RP", 1},
        {"tkBRC_LP", 2}
    };

    set<string> NO_NL_CMT {"tkNL", "tkCMT"};
	set<string> ft_tkTYPES_NONE;
	set<string> ft_tkTYPES_0 {"tkNL"};
	set<string> ft_tkTYPES_1 {"tkSTN", "tkVAR"};
	set<string> ft_tkTYPES_2 {"tkASG", "tkSTR", "tkAVAL"};
	set<string> ft_tkTYPES_3 {"tkFVAL", "tkSTR", "tkDLS", "tkTBD"};
	set<string> ft_tkTYPES_4 {"tkDLS", "tkASG"};

	const char ichar = fmt.ichar;
	const int iamount = fmt.iamount;

    vector<string> cleaned;
    for (auto const &branch : branches) {

        string parentkind = branch[0].kind;

        bool first_assignment = false;
        int level = 0;

        int brc_lp_count = 0;
        bool group_open = false;

		int j = 0;
		for (auto const &leaf : branch) {
            int tid = leaf.tid;
            string kind = leaf.kind;
            int line = leaf.line;

            //// Settings / Variables

            if (contains(ft_tkTYPES_1, parentkind)) {
                if (kind == "tkTRM") continue;

                if (tid != 0) {
                    Token& ptk = S.LexerData.tokens[prevtoken(S, tid, ft_tkTYPES_0)];
                    int dline = line - ptk.line;
                    if (contains(ft_tkTYPES_2, kind)) {
                        if (ptk.kind == "tkCMT") {
                            cleaned.push_back("\n");
                            if (dline > 1) cleaned.push_back("\n");
						}
                        cleaned.push_back(" ");
                    } else {
                        if      (dline == 0) cleaned.push_back(" ");
                        else if (dline == 1) cleaned.push_back("\n");
                        else                 cleaned.push_back("\n\n");
                   	}
				}

                cleaned.push_back(tkstr(S, leaf.tid));

            //// Command chains

			} else if (parentkind == "tkCMD") {

                if (tid != 0) {
                    Token& ptk = tokens[prevtoken(S, tid, ft_tkTYPES_0)];
                    int dline = line - ptk.line;

                    if (dline == 1) {
                    	cleaned.push_back("\n");
                    } else if (dline > 1) {
                        cleaned.push_back("\n");
                        cleaned.push_back("\n");

                        // [TODO] Add format settings to customize formatting.
                        // For example, collapse newlines in flag scopes?
                        // if level > 0: cleaned.pop()
					}
				}

                // When inside an indentation level or inside parenthesis,
                // append a space before every token to space things out.
                // However, because this is being done lazily, some token
                // conditions must be skipped. The skippable cases are when
                // a '$' precedes a string (""), i.e. a '$"command"'. Or
                // when an eq-sign precedes a '$', i.e. '=$("cmd")',
                if ((level || brc_lp_count == 1) &&
                    contains(ft_tkTYPES_3, kind)) {
                    Token& ptk = tokens[prevtoken(S, tid, NO_NL_CMT)];
                    string pkind = ptk.kind;

                    if (pkind != "tkBRC_LP" && cleaned.back() != " " && not
                        ((kind == "tkSTR" && pkind == "tkDLS") ||
                        (kind == "tkDLS" && pkind == "tkASG"))) {
                        cleaned.push_back(" ");
		            }
                }

                if (kind == "tkBRC_LC") {
                    group_open = true;
                    cleaned.push_back(tkstr(S, leaf.tid));

                } else if (kind == "tkBRC_RC") {
                    group_open = false;
                    cleaned.push_back(tkstr(S, leaf.tid));

                } else if (kind == "tkDCMA" && !first_assignment) {
                    cleaned.push_back(tkstr(S, leaf.tid));
                    // Append newline after group is cloased.
                    if (!group_open) cleaned.push_back("\n");

                } else if (kind == "tkASG" && !first_assignment) {
                    first_assignment = true;
                    cleaned.push_back(" ");
                    cleaned.push_back(tkstr(S, leaf.tid));
                    cleaned.push_back(" ");

                } else if (kind == "tkBRC_LB") {
                    cleaned.push_back(tkstr(S, leaf.tid));
                    level = 1;

                } else if (kind == "tkBRC_RB") {
                    level = 0;
                    first_assignment = false;
                    cleaned.push_back(tkstr(S, leaf.tid));

                } else if (kind == "tkFLG") {
                    if (level) cleaned.push_back(indent(kind, level, ichar, iamount, MXP));
                    cleaned.push_back(tkstr(S, leaf.tid));

                } else if (kind == "tkKYW") {
                    if (level) cleaned.push_back(indent(kind, level, ichar, iamount, MXP));
                    cleaned.push_back(tkstr(S, leaf.tid));
                    cleaned.push_back(" ");

                } else if (kind == "tkFOPT") {
                    level = 2;
                    cleaned.push_back(indent(kind, level, ichar, iamount, MXP));
                    cleaned.push_back(tkstr(S, leaf.tid));

                } else if (kind == "tkBRC_LP") {
                    brc_lp_count += 1;
                    Token& ptk = tokens[prevtoken(S, tid, ft_tkTYPES_0)];
                    string pkind = ptk.kind;
                    if (!contains(ft_tkTYPES_4, pkind)) {
                        int scope_offset = int(pkind == "tkCMT");
                        cleaned.push_back(indent(kind, level + scope_offset, ichar, iamount, MXP));
					}
                    cleaned.push_back(tkstr(S, leaf.tid));

                } else if (kind == "tkBRC_RP") {
                    brc_lp_count -= 1;
                    if (level == 2 && !brc_lp_count &&
                           branch[j - 1].kind != "tkBRC_LP") {
                        cleaned.push_back(indent(kind, level - 1, ichar, iamount, MXP));
                        level = 1;
					}
                    cleaned.push_back(tkstr(S, leaf.tid));

                } else if (kind == "tkCMT") {
                    string ptk = tokens[prevtoken(S, leaf.tid, ft_tkTYPES_NONE)].kind;
                    string atk = tokens[prevtoken(S, tid, ft_tkTYPES_0)].kind;
                    if (ptk == "tkNL") {
                        int scope_offset = 0;
                        if (atk == "tkASG") scope_offset = 1;
                        cleaned.push_back(indent(kind, level + scope_offset, ichar, iamount, MXP));
                    } else cleaned.push_back(" ");
                    cleaned.push_back(tkstr(S, leaf.tid));

                } else {
                    cleaned.push_back(tkstr(S, leaf.tid));
                }

            //// Comments

            } else if (parentkind == "tkCMT") {
                if (tid != 0) {
                    Token& ptk = tokens[prevtoken(S, tid, ft_tkTYPES_0)];
                    int dline = line - ptk.line;

                    if (dline == 1) {
                        cleaned.push_back("\n");
                    } else {
                        cleaned.push_back("\n");
                        cleaned.push_back("\n");
					}
				}
                cleaned.push_back(tkstr(S, leaf.tid));

            } else {
                if (kind != "tkTRM") {
                    cleaned.push_back(tkstr(S, leaf.tid));
                }
            }

            j++;
		}
	}

    // Return empty values to maintain parity with acdef.py.

	string formatted = join(cleaned, "") + "\n";

	tuple <string, string, string, string, string, string, map<string, string>, string> data;
	map<string, string> placeholders;
	data = make_tuple("", "", "", "", "", formatted, placeholders, "");

	return data;
}
