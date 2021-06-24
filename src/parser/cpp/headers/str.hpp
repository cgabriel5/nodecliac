#ifndef STR_HPP
#define STR_HPP

#include <string>
#include <array>
#include <vector>

using namespace std;

bool eq(const string &s1, const string &s2);
// string join(string *paths, int size, const string &delimiter);
void split(vector<string> &reflist, string src,
	const string &delimiter="\n");

// [https://stackoverflow.com/a/2072890]
// [https://stackoverflow.com/a/1421730]
inline bool endswith(string const &value, string const &ending) {
	if (ending.size() > value.size()) return false;
	return equal(ending.rbegin(), ending.rend(), value.rbegin());
}

// [https://www.delftstack.com/howto/cpp/how-to-trim-a-string-cpp/]
// [https://stackoverflow.com/a/25385766]
// [https://stackoverflow.com/a/217605]
// [https://stackoverflow.com/a/29892589]
// [https://www.techiedelight.com/trim-string-cpp-remove-leading-trailing-spaces/]
const string WS_CHARS = " \t\n\r\f\v";
// string& ltrim(string &str, const string &charlist);
string& ltrim(string &str, const string &charlist=WS_CHARS);
// string& rtrim(string &str, const string &charlist);
string& rtrim(string &str, const string &charlist=WS_CHARS);
// string& trim(string &str, const string &charlist);
string& trim(string &str, const string &charlist=WS_CHARS);

// Use template function: [https://stackoverflow.com/a/10632266]
// [https://www.techiedelight.com/pass-array-by-value-to-function/]
// [https://stackoverflow.com/a/21444760]
// [https://www.codesdope.com/cpp-stdarray/]
// [http://www.cplusplus.com/forum/general/184301/#msg901210]
// [https://stackoverflow.com/a/50321144]
// [https://stackoverflow.com/a/23188406]
// [https://stackoverflow.com/a/17156297]
// [https://www.learncpp.com/cpp-tutorial/an-introduction-to-stdarray/]
// [https://rules.sonarsource.com/cpp/RSPEC-5945]
#include "str.tcc"

string join(const vector<string> &container, const string &delimiter);

#endif
