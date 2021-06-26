#ifndef FORMATTER_HPP
#define FORMATTER_HPP

#include "./structs.hpp"

#include <tuple>
#include <string>
#include <vector>
#include <map>

using namespace std;

tuple <string, string, string, string, string, string, map<string, string>, string>
	formatter(StateParse &S,
	vector<vector<Token>> &BRANCHES,
	vector<vector<vector<int>>> &cchains,
	map<int, vector<Flag>> &flags,
	vector<vector<int>> &settings);

#endif
