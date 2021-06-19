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
template<size_t N>
void appendA(array<string, N> &arr);
#include "str.tcc"

#endif