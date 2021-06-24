#ifndef PARSETOOLS_HPP
#define PARSETOOLS_HPP

#include "./structs.hpp"

#include <string>

using namespace std;

string tkstr(LexerResponse &LexerData, const string &text, const int tid);

#endif
