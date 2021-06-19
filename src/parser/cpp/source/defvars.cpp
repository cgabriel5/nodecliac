#ifndef DEFVARS_HPP
#define DEFVARS_HPP

#include <string>
#include <map>
#include <unistd.h>
#include <sys/types.h>
#include <pwd.h>

using namespace std;

// [https://stackoverflow.com/a/8249232]
// [https://stackoverflow.com/a/42040500]
#if defined(__linux__)
	#define PLATFORM "Linux"
#elif defined(__APPLE__)
	#define PLATFORM "Darwin"
#elif defined(_WIN32)
    #define PLATFORM "Windows"
#endif

// Builtin variables.
map<string, string> builtins(const string cmdname) {
	// [https://stackoverflow.com/a/26696759]
	const char *homedir;
	if ((homedir = getenv("HOME")) == NULL) {
		homedir = getpwuid(getuid())->pw_dir;
	}
	string hdir = homedir;

	map<string, string> builtins {
		{"HOME", hdir},
		{"OS", PLATFORM},
		{"COMMAND", cmdname},
		{"PATH", hdir + "/.nodecliac/registry/" + cmdname},
	};

	return builtins;
}

#endif
