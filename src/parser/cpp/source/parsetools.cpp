#include "./structs.hpp"

#include <string>

using namespace std;

string tkstr(LexerResponse &LexerData, const string &text, const int tid) {
	if (tid == -1) return "";
	// Return interpolated string for string tokens.
	if (LexerData.tokens[tid].kind == "tkSTR") {
		if (!LexerData.tokens[tid].$.empty()) return LexerData.tokens[tid].$;
	}
	int start = LexerData.tokens[tid].start;
	int end = LexerData.tokens[tid].end;
	return text.substr(start, end - start + 1);
}
