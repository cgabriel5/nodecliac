#ifndef ACDEF_HPP
#define ACDEF_HPP

#include <tuple>
#include <string>
#include <vector>
#include <map>

using namespace std;

tuple <string, string, string, string, string, string, map<string, string>, string>
	acdef(vector<vector<Token>> &branches,
			vector<vector<vector<int>>> &cchains,
			map<int, vector<Flag>> &flags,
			vector<vector<int>> &settings,
			StateParse &S, LexerResponse &LexerData,
			string const &cmdname,
			string const &text
			);

#endif
