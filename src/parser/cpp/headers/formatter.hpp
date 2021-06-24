#ifndef FORMATTER_HPP
#define FORMATTER_HPP

#include "./structs.hpp"

#include <tuple>
#include <string>
#include <vector>
#include <map>

using namespace std;

tuple <string, string, string, string, string, string, map<string, string>, string>
	formatter(vector<Token> &tokens,
	const string &text,
	vector<vector<Token>> &BRANCHES,
	vector<vector<vector<int>>> &cchains,
	map<int, vector<Flag>> &flags,
	vector<vector<int>> &settings,
	StateParse &S,
	LexerResponse &LexerData);

#endif
