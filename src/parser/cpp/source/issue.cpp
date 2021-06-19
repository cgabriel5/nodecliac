#include <string>

#include <termcolor.hpp>  // [https://github.com/ikalnytskyi/termcolor]

using namespace std;

void issue_hint(const string &filename, int line, int col, const string &message) {
	string itype = "\033[32;1mHint:\033[0m";
	string fileinfo = "\033[1m" + filename + "(" + to_string(line) + ", " + to_string(col) + ")\033[0m";

	cout << fileinfo << " " << itype << " " << message << endl;
}

void issue_warn(const string &filename, int line, int col, const string &message) {
	string itype = "\033[33;1mWarning:\033[0m";
	string fileinfo = "\033[1m" + filename + "(" + to_string(line) + ", " + to_string(col) + ")\033[0m";

	cout << fileinfo << " " << itype << " " << message << endl;
}

void issue_error(const string &filename, int line, int col, const string &message) {
	string itype = "\033[31;1mError:\033[0m";
	string fileinfo = "\033[1m" + filename + "(" + to_string(line) + ", " + to_string(col) + ")\033[0m";

	cout << fileinfo << " " << itype << " " << message << endl;
	exit(1);
}
