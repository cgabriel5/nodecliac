#include "fs.hpp"
#include "str.hpp"

#include <string>
#include <vector>

#include <filesystem.hpp> // [https://github.com/gulrak/filesystem]

using namespace std;
namespace fs = ghc::filesystem;

void info(const string &p, FileInfo &refobj) {
	// [https://stackoverflow.com/a/38463871]
	// [https://stackoverflow.com/a/48518157]
	fs::path path(p);
	string head = path.parent_path();
	string name = path.filename();
	string ext = path.extension();

	refobj.dirname = head;
	refobj.path = p;

	if (!ext.empty()) {
		refobj.name = name;
		ext.erase(0, 1); // Remove '.'.
		refobj.ext = ext;
	} else {
		// [https://stackoverflow.com/a/65373164]
		char sep = fs::path::preferred_separator;
		// [https://stackoverflow.com/a/64407571]
		string delimiter{sep}; // Char to string.

		vector<string> path_parts;
		split(path_parts, &p, delimiter);

		if (!path_parts.empty()) {
			// [https://stackoverflow.com/a/14275320]
			name = path_parts.back();
			size_t index = name.find_last_of('.');
			if (index != string::npos) {
				refobj.name = name;
				refobj.ext = name.substr(index + 1);
			}
		}
	}
}
