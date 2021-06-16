#ifndef PARSER_HPP
#define PARSER_HPP

#include <string>

using namespace std;

struct tabdata { char ichar; int iamount; };

string parser(const string &action, const string &text,
	const string &cmdname, const string &source,
	const tabdata &fmt, const bool &trace,
	const bool &igc, const bool &test);

#endif
