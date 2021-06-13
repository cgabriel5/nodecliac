#include "io.hpp"

#include <string>
#include <fstream>
#include <sstream>

using namespace std;

// [https://www.cplusplus.com/doc/tutorial/files/]
// [https://stackoverflow.com/a/19922123]
// [https://stackoverflow.com/q/748014]
void read(const string &p, string &buffer) {
	ifstream f;
	f.open(p);
	stringstream strStream;
	strStream << f.rdbuf();
	buffer = strStream.str();
}

// [https://www.cplusplus.com/doc/tutorial/files/]
void write(const string &p, const string &data) {
	ofstream f;
	f.open(p);
	f << data;
	f.close();
}
