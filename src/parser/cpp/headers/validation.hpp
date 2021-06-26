#ifndef VALIDATION_HPP
#define VALIDATION_HPP

#include "../headers/structs.hpp"

#include <string>

using namespace std;

void vsetting(StateParse &S);
void vvariable(StateParse &S);
void vstring(StateParse &S);
void vsetting_aval(StateParse &S);

#endif
