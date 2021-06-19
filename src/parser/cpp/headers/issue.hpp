#ifndef ISSUE_HPP
#define ISSUE_HPP

#include <string>

using namespace std;

void issue_hint(const string &filename, int line, int col, const string &message);
void issue_warn(const string &filename, int line, int col, const string &message);
void issue_error(const string &filename, int line, int col, const string &message);

#endif
