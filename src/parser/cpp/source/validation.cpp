#include "../headers/structs.hpp"
#include "../headers/issue.hpp"

#include <string>
#include <vector>
#include <set>
#include <regex>
#include <iostream>

using namespace std;

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

void vsetting(StateParse &S, LexerResponse &LexerData, const string &text) {
	Token token = LexerData.tokens[S.tid];
	int start = token.start;
	int end = token.end;
	int line = token.line;
	int index = token.start;
	int col = index - LexerData.LINESTARTS[line];

	vector<string> settings {"compopt", "filedir", "disable", "placehold", "test"};

	string setting = text.substr(start, end - start);

	// Warn if setting is not a supported setting.
	if (!contains(settings, setting)) {
		string message = "Unknown setting: '" + setting + "'";

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
}

void vvariable(StateParse &S, LexerResponse &LexerData, const string &text) {
	Token token = LexerData.tokens[S.tid];
	int start = token.start;
	int end = token.end;
	int line = token.line;
	int index = token.start;
	int col = index - LexerData.LINESTARTS[line];

	// Error when variable starts with a number.
	if (isdigit(S.text[start + 1])) {
		std::string chstr{S.text[start + 1]};
		string message = "Unexpected: '" + chstr + "'";
		message += "\n\033[1;36mInfo\033[0m: Variable cannot begin with a number.";
		issue_error(S.filename, line, col, message);
	}
}

void vstring(StateParse &S, LexerResponse &LexerData, const string &text) {
	Token token = LexerData.tokens[S.tid];
	int start = token.start;
	int end = token.end;
	int line = token.lines[0];
	int index = token.start;
	int col = index - LexerData.LINESTARTS[line];

	// Warn when string is empty.
	// [TODO] Warn if string content is just whitespace?
	if (end - start == 1) {
		string message = "Empty string";

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

	// Error if string is unclosed.
	if (token.lines[1] == -1) {
		string message = "Unclosed string";
		issue_error(S.filename, line, col, message);
	}
}

void vsetting_aval(StateParse &S, LexerResponse &LexerData, const string &text) {
	Token token = LexerData.tokens[S.tid];
	int start = token.start;
	int end = token.end;
	int line = token.line;
	int index = token.start;
	int col = index - LexerData.LINESTARTS[line];

	vector<string> values {"true", "false"};

	string value = text.substr(start, end - start);

	// Warn if values is not a supported values.
	if (!contains(values, value)) {
		string message = "Invalid setting value: '" + value + "'";
		issue_error(S.filename, line, col, message);
	}
}
