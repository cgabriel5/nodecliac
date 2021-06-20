#ifndef ACDEF_HPP
#define ACDEF_HPP

#include <string>
#include <vector>
#include <map>

using namespace std;

void acdef(vector<vector<Token>> &branches,
			vector<vector<vector<int>>> &cchains,
			map<int, vector<Flag>> &flags,
			vector<vector<int>> &settings,
			StateParse &S, LexerResponse &LexerData, string const &cmdname);

#endif
