#include "io.hpp"
#include "path.hpp"
#include "str.hpp"
#include "fs.hpp"
#include "parser.hpp"

#include <tuple>
#include <array>
#include <vector>
#include <regex>
#include <fstream>
#include <sstream>
#include <iostream>
#include <stdlib.h>

#include <cxxopts.hpp>    // [https://github.com/jarro2783/cxxopts]
#include <termcolor.hpp>  // [https://github.com/ikalnytskyi/termcolor]
#include <filesystem.hpp> // [https://github.com/gulrak/filesystem]

using namespace std;
namespace fs = ghc::filesystem;

int main(int argc, char **argv) {

	if (argc == 1) exit(1);

	cxxopts::Options options("", "");

	options
		// [https://github.com/jarro2783/cxxopts/pull/105]
		.allow_unrecognised_options()
		.add_options()
			("igc", "",    cxxopts::value<bool>()->default_value("false"))
			("test", "",   cxxopts::value<bool>()->default_value("false"))
			("print", "",  cxxopts::value<bool>()->default_value("false"))
			("trace", "",  cxxopts::value<bool>()->default_value("false"))
			("action", "", cxxopts::value<string>())
			("indent", "", cxxopts::value<string>()->default_value("s:4"))
			("source", "", cxxopts::value<string>()->default_value(""))
			("positional", "", cxxopts::value<vector<string>>());
	options.parse_positional({"action", "positional"});
	auto result = options.parse(argc, argv);

	bool igc = result["igc"].as<bool>();
	bool test = result["test"].as<bool>();
	bool print = result["print"].as<bool>();
	bool trace = result["trace"].as<bool>();
	string action;
	string indent;
	string source;
	if (result.count("action")) action = result["action"].as<string>();
	if (result.count("indent")) indent = result["indent"].as<string>();
	if (result.count("source")) source = result["source"].as<string>();
	bool formatting = action == "format";

	// [https://stackoverflow.com/a/11516847]
	tabdata fmtinfo = {'\t', 1}; // (char, amount)
	// Parse/validate indentation.
	if (formatting && indent != "") {
		regex r("^(s|t):\\d+$");
		if (!regex_match(indent, r)) {
			cout << "Invalid indentation string." << endl;
			exit(1);
		}
		vector<string> components;
		split(components, indent, ":");
		fmtinfo.ichar = (eq(components[0], "s") ? ' ' : '\t');
		fmtinfo.iamount = std::stoi(components[1]);
	}

	// Source must be provided.
	if (source.empty()) {
		cout << "Please provide a " << termcolor::bold << "--source"
			<< termcolor::reset << " path." << endl;
		exit(1);
	}

	// Breakdown path.
	FileInfo fi;
	info(source, fi);
	string extension = fi.ext;
	regex e("\\." + extension + "$");
	string cmdname = std::regex_replace(fi.name, e, "");
	string dirname = abspath(fi.dirname);

	// Make path absolute.
	// [https://stackoverflow.com/a/43278300]
	// [https://stackoverflow.com/a/62728759]
	const fs::path path(source);
	if (!path.is_absolute()) {
		// fs::absolute does not fully resolve path.
		// source = fs::absolute(source);
		source = abspath(source);
	}

	// [https://stackoverflow.com/a/43281413]
	if (fs::is_directory(path)) {
		cout << "Directory provided but .acmap file path needed." << endl;
		exit(1);
	}
	if (!fs::is_regular_file(path)) {
		cout << "Path " << termcolor::bold << source << termcolor::reset
			<< " doesn't exist." << endl;
		exit(1);
	}

	string res;
	read(source, res);

	string acdef, config, keywords, filedirs, contexts, formatted, tests;
	map<string, string> placeholders;

	tuple <string, string, string, string, string, string, map<string, string>, string> data;
	data = parser(action, res, cmdname, source, fmtinfo, trace, igc, test);
	tie(acdef, config, keywords, filedirs, contexts, formatted, placeholders, tests) = data;

	string testname = cmdname + ".tests.sh";
	string savename = cmdname + ".acdef";
	string saveconfigname = "." + cmdname + ".config.acdef";

	// Only save files to disk when not testing.
	if (!test) {
		if (formatting) {
			write(source, formatted);
		} else {
			// [https://stackoverflow.com/a/36848326]
			// [https://stackoverflow.com/a/65373164]
			char sep = fs::path::preferred_separator;
			// [https://stackoverflow.com/a/64407571]
			string delimiter{sep}; // Char to string.

			array<string, 2> paths = {dirname};
			paths.at(1) = testname;
			string testpath = join(paths, delimiter);
			paths.at(1) = savename;
			string commandpath = join(paths, delimiter);
			paths.at(1) = saveconfigname;
			string commandconfigpath = join(paths, delimiter);
			paths.at(1) = "placeholders";
			string placeholderspaths = join(paths, delimiter);

			// [https://en.cppreference.com/w/cpp/experimental/fs/create_directory]
			fs::create_directories(dirname);

			write(commandpath, acdef + keywords + filedirs + contexts);
			write(commandconfigpath, config);

			// Save test file if tests were provided.
			if (!tests.empty()) {
				write(testpath, tests);
				// [https://stackoverflow.com/a/51360779]
				// [https://stackoverflow.com/a/9288614]
				// [http://permissions-calculator.org/]
				// [https://stackoverflow.com/a/46834921]
				// [https://en.cppreference.com/w/cpp/filesystem/permissions]
				// [https://stackoverflow.com/a/37234575]
				// [https://www.ibm.com/docs/en/zos/2.2.0?topic=functions-chmod-change-mode-file-directory]
				fs::permissions(testpath,
					fs::perms::owner_all | fs::perms::group_all |
					fs::perms::others_read | fs::perms::others_exec,
					fs::perm_options::add);
			}

			// Create placeholder files if object is populated.
			// placeholders = placeholders
			if (placeholders.size()) {
				fs::create_directories(placeholderspaths);

				for (auto const &it : placeholders) {
					string p = placeholderspaths + sep + it.first;
					write(p, placeholders[it.first]);
				}
			}
		}
	}

	if (print) {
		if (!formatting) {
			if (!acdef.empty()) {
				cout << "[" << termcolor::bold << cmdname + ".acdef"
					<< termcolor::reset << "]\n" << endl;
				cout << (acdef + keywords + filedirs + contexts) << endl;
				if (config.empty()) { cout << "" << endl; }
			}
			if (!config.empty()) {
				cout << "\n[" << termcolor::bold
					<<  "." + cmdname + ".config.acdef"
					<< termcolor::reset << "]\n" << endl;
				cout << config << endl;
			}
		} else { cout << formatted << endl; }
	}

	// Test (--test) purposes.
	if (test) {
		if (!formatting) {
			if (!acdef.empty()) {
				cout << (acdef + keywords + filedirs + contexts) << endl;
				if (config.empty()) { cout << "" << endl; }
			}
			if (!config.empty()) {
				if (!acdef.empty()) { cout << "" << endl; }
				cout << config << endl;
			}
		} else { cout << formatted << endl; }
	}

	return 0;

}
