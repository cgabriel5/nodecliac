#ifndef STRUCTS_HPP
#define STRUCTS_HPP

#include <string>
#include <array>
#include <vector>
#include <map>

using namespace std;

struct Token {
	string kind, $;
	int line, start, end, tid;
	array<int, 2> lines = {-1, -1};
};

struct LexerResponse {
	vector<Token> tokens;
	map<int, string> ttypes;
	vector<int> ttids;
	map<int, int> dtids;
	map<int, int> LINESTARTS {{1, -1}};
};

struct State {
	int i, line, start, end;
	string kind;
	bool last, list;
	array<int, 2> lines;
};

#endif
