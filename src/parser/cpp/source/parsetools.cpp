#include "./structs.hpp"

#include <string>

using namespace std;

string tkstr(StateParse &S, const int &tid) {
	if (tid == -1) return "";
	// Return interpolated string for string tokens.
	Token &tk = S.LexerData.tokens[tid];
	if (tk.kind == "tkSTR") {
		if (!tk.$.empty()) return tk.$;
	}
	int start = tk.start;
	int end = tk.end;
	return S.text.substr(start, end - start + 1);
}
