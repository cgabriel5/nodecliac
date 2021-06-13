#include "str.hpp"
#include <string>
#include <vector>

using namespace std;

// [https://www.tutorialkart.com/cpp/cpp-string-equals/]
bool eq(const string &s1, const string &s2) {
	return s1.compare(s2) == 0;
}

// [https://stackoverflow.com/a/11829889]
// [https://www.oreilly.com/library/view/c-cookbook/0596007612/ch04s09.html]
// [https://stackoverflow.com/a/40497964]
string join(string *paths, int size, const string &delimiter) {
	string buffer = "";
	for (int i = 0; i < size; i++) {
		// [https://stackoverflow.com/a/611352]
		buffer += paths[i];
		if (i + 1 < size) buffer += delimiter;
	}
	return buffer;
}

// [https://stackoverflow.com/a/44495206]
void split(vector<string> &reflist, const string* src,
	const string &delimiter /*="\n"*/) {

	string token;
	size_t pos = 0;
	string s = *src;
	while ((pos = s.find(delimiter)) != string::npos) {
		token = s.substr(0, pos);
		reflist.push_back(token);
		s.erase(0, pos + delimiter.length());
	}
	reflist.push_back(s);
}
