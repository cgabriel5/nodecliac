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
// string join(string *paths, int size, const string &delimiter) {
// 	string buffer = "";
// 	for (int i = 0; i < size; i++) {
// 		// [https://stackoverflow.com/a/611352]
// 		buffer += paths[i];
// 		if (i + 1 < size) buffer += delimiter;
// 	}
// 	return buffer;
// }

// [https://www.delftstack.com/howto/cpp/how-to-trim-a-string-cpp/]
// [https://stackoverflow.com/a/25385766]
// [https://stackoverflow.com/a/217605]
// [https://stackoverflow.com/a/29892589]
// [https://www.techiedelight.com/trim-string-cpp-remove-leading-trailing-spaces/]
string& ltrim(string &str, const string &charlist)  {
	str.erase(0, str.find_first_not_of(charlist));
	return str;
}

string& rtrim(string &str, const string &charlist) {
	str.erase(str.find_last_not_of(charlist) + 1);
	return str;
}

string& trim(string &str, const string &charlist) {
	return ltrim(rtrim(str));
}

// [https://stackoverflow.com/a/44495206]
void split(vector<string> &reflist, string src,
	const string &delimiter /*="\n"*/) {

	// [TODO]: Re-work to avoid making source string copy.

	string token;
	size_t pos = 0;
	while ((pos = src.find(delimiter)) != string::npos) {
		token = src.substr(0, pos);
		reflist.push_back(token);
		src.erase(0, pos + delimiter.length());
	}
	reflist.push_back(src);
}
