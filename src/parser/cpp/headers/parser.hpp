#ifndef PARSER_HPP
#define PARSER_HPP

#include "./structs.hpp"

#include <tuple>
#include <string>

using namespace std;

tuple <string, string, string, string, string, string, map<string, string>, string>
	parser(const string &action, string &text,
	const string &cmdname, const string &source,
	const tabdata &fmt, const bool &trace,
	const bool &igc, const bool &test);

#endif
