#ifndef FS_HPP
#define FS_HPP

#include <string>

using namespace std;

struct FileInfo { string name, dirname, ext, path; };
void info(const string &p, FileInfo &refobj);

#endif
