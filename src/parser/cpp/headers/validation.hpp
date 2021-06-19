#ifndef VALIDATION_HPP
#define VALIDATION_HPP

#include "../headers/structs.hpp"

#include <string>

using namespace std;

void vsetting(StateParse &S, LexerResponse &LexerData, const string &text);
void vvariable(StateParse &S, LexerResponse &LexerData, const string &text);
void vstring(StateParse &S, LexerResponse &LexerData, const string &text);
void vsetting_aval(StateParse &S, LexerResponse &LexerData, const string &text);

#endif
