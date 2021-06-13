#include "path.hpp"

#include <filesystem.hpp> // [https://github.com/gulrak/filesystem]

#include <string>

using namespace std;

string abspath(const string &p) {
	// [https://www.geeksforgeeks.org/convert-string-char-array-cpp/]
	// [https://stackoverflow.com/a/36686269]
	// [https://stackoverflow.com/a/2341857]
	// [https://www.oreilly.com/library/view/c-cookbook/0596007612/ch10s18.html]
	char path[p.length() + 1];
	strcpy(path, p.c_str());
	char resolved_path[PATH_MAX];
	realpath(path, resolved_path);
	return string(resolved_path); // [https://stackoverflow.com/a/25576379]
}
