#ifndef STRUCTS_HPP
#define STRUCTS_HPP

#include <string>
#include <array>
#include <vector>
#include <map>
#include <set>

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

// -----------------------------------------------------------------------------

struct tabdata {
	char ichar;
	int iamount;
};

struct Args {
	string action, source;
	tabdata fmt;
	bool trace, igc, test;
};

struct Warning {
	string filename, message;
	int line, column;
};

struct StateParse {
	int tid = -1;
	string filename; // = source;
	string text; // = text;
	LexerResponse LexerData;
	Args args;
	vector<int> ubids;
	vector<string> excludes;
	map<int, vector<Warning>> warnings;
	set<int> warn_lines;
	set<int> warn_lsort;
};

struct Flag {
	int tid = -1;
	int alias = -1;
	int boolean = -1;
	int assignment = -1;
	int multi = -1;
	int union_ = -1;
	vector<vector<int>> values;
};

#endif
