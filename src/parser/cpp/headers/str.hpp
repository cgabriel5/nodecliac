#ifndef STR_HPP
#define STR_HPP

#include <string>
#include <vector>

using namespace std;

bool eq(const string &s1, const string &s2);
string join(string *paths, int size, const string &delimiter);
void split(vector<string> &reflist, const string* src,
	const string &delimiter="\n");

#endif
