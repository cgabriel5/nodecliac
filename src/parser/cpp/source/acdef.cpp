#include "../headers/templates.hpp"
#include "../headers/structs.hpp"
#include "../headers/str.hpp"
#include "../headers/parsetools.hpp"

#include <tuple>
#include <string>
#include <vector>
#include <map>
#include <unordered_map>
#include <set>
#include <regex>
#include <iostream>
#include <ctime>
#include <chrono>
#include <cstdint>
#include <iostream>
#include <algorithm>

#include <ordered_map.h> // [https://github.com/Tessil/ordered-map]
#include "../libs/md5.h" // [http://www.zedwood.com/article/cpp-md5-function]

using namespace std;

map<string, map<string, int>> oSets;
// [https://stackoverflow.com/a/44700641]
map<string, tsl::ordered_map<string, int>> oDefaults;
map<string, tsl::ordered_map<string, int>> oFiledirs;
map<string, tsl::ordered_map<string, int>> oContexts;

vector<map<string, tsl::ordered_map<string, int>>> oKeywords {oDefaults, oFiledirs, oContexts};

vector<Flag> ubflags;

tsl::ordered_map<string, string> oSettings;
int settings_count = 0;
vector<string> oTests;
map<string, string> oPlaceholders;
map<string, string> omd5Hashes;
string acdef_ = "";
vector<string> acdef_lines;
string config = "";
string defaults = "";
string filedirs = "";
string contexts = "";
bool has_root = false;

regex re_cmdname;
regex re_space("\\s");
regex re_space_cl(";\\s+");

// [https://stackoverflow.com/a/56107709]
uint64_t timeSinceEpochMillisec() {
  using namespace std::chrono;
  return duration_cast<milliseconds>(system_clock::now().time_since_epoch()).count();
}

struct Cobj {
	int i, m;
	string val, orig;
	bool single = 0;
};

Cobj aobj(string s) {
	// [https://stackoverflow.com/a/3403868]
	transform(s.begin(), s.end(), s.begin(), ::tolower);
	Cobj o;
	o.val = s;
	return o;
}

const char C_HYPHEN = '-';

Cobj fobj(string s) {
	Cobj o;
	o.orig = s;
	o.val = s;
	transform(o.val.begin(), o.val.end(), o.val.begin(), ::tolower);
	o.m = endswith(s, "=*");
	if (s[1] != C_HYPHEN) {
		o.orig = s;
		o.single = true;
	}

	return o;
}

bool asort(const Cobj &a, const Cobj &b) {
	// Resort to string length.
	bool result = b.val > a.val;

	// Finally, resort to singleton.
	if (!result && a.single && b.single) {
		result = a.orig < b.orig;
	}

	return result;
}

// compare function: Gives precedence to flags ending with '=*' else
//     falls back to sorting alphabetically.
//
// @param  {string} a - Item a.
// @param  {string} b - Item b.
// @return {number} - Sort result.
//
// Give multi-flags higher sorting precedence:
// @resource [https://stackoverflow.com/a/9604891]
// @resource [https://stackoverflow.com/a/24292023]
// @resource [http://www.javascripttutorial.net/javascript-array-sort/]
// let sort = (a, b) => ~~b.endsWith("=*") - ~~a.endsWith("=*") || asort(a, b)
bool fsort(const Cobj &a, const Cobj &b) {
	// [https://stackoverflow.com/a/16894796]
	// [https://www.cplusplus.com/articles/NhA0RXSz/]
	// [https://stackoverflow.com/a/6771418]
	bool result = false;

	// Give multi-flags precedence.
	if (a.m || b.m) {
		result = b.m < a.m;
	} else {
		result = asort(a, b);
	}

	return result;
}

// Uses map sorting to reduce redundant preprocessing on array items.
//
// @param  {array} A - The source array.
// @param  {function} comp - The comparator function to use.
// @return {array} - The resulted sorted array.
//
// @resource [https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/sort]
// [https://www.codingame.com/playgrounds/15869/c-runnable-snippets/passing-a-function-as-parameter]
vector<string> mapsort(vector<string> &A,
		bool (*comp)(const Cobj &a, const Cobj &b),
		Cobj (*comp_obj)(string s)) {

	vector<Cobj> T; // Temp array.
	// [https://stackoverflow.com/a/31009108]
	vector<string> R(A.size()); // Result array.

	// Short-circuit when source array is empty.
	if (A.empty()) return R;

	Cobj obj;
	int i = 0;
	for (auto const &a : A) {
		obj = comp_obj(a);
		obj.i = i;
		T.push_back(obj);
		i++;
	}
	// [https://stackoverflow.com/a/873725]
	// [https://stackoverflow.com/a/1380496]
	sort(T.begin(), T.end(), comp);

	i = 0;
	for (auto const &item : T) {
		R[i] = A[T[i].i];
		i++;
	}
	return R;
}

// Removes first command in command chain. However, when command name
// is not the main command in (i.e. in a test file) just remove the
// first command name in the chain.
//
// @param  {string} command - The command chain.
// @return {string} - Modified chain.
string rm_fcmd(string chain, const regex &r) {
	return regex_replace(chain, r, "");
}

string get_cmdstr(StateParse &S, int start, int stop) {
	vector<string> output;
	const set<string> allowed_tk_types {"tkSTR", "tkDLS"};
	for (int tid = start; tid < stop; tid++) {
		if (contains(allowed_tk_types, S.LexerData.tokens[tid].kind)) {
			if (!output.empty() && output.back() == "$") {
				output.back() = "$" + tkstr(S, tid);
			} else {
				output.push_back(tkstr(S, tid));
			}
		}
	}
	return "$(" + join(output, ",") + ")";
}

string strreplace(string s, string sub, string replacement) {
	// [https://stackoverflow.com/a/2340309]
	// [https://www.cplusplus.com/reference/string/string/replace/]
	int index = s.find(sub);
	if (index != std::string::npos) {
		s.replace(index, sub.length(), replacement);
	}
	return s;
}

void processflags(StateParse &S, int gid,
	const string &chain,
	const vector<Flag> &flags,
	map<string, int> &queue_flags,
	bool recunion=false,
	bool recalias=false
	) {

	vector<Flag> unions;
	for (auto const &flg : flags) {
		int tid = flg.tid;
		string assignment = tkstr(S, flg.assignment);
		string boolean = tkstr(S, flg.boolean);
		string alias = tkstr(S, flg.alias);
		string flag = tkstr(S, tid);
		string ismulti = tkstr(S, flg.multi);
		bool union_ = flg.union_ != -1;
		const vector<vector<int>> &values = flg.values;

		string &kind = S.LexerData.tokens[tid].kind;

		if (!alias.empty() && !recalias) {
			vector<Flag> list {flg};
			processflags(S, gid, chain, list, queue_flags,
				/*recunion=*/false, /*recalias=*/true);
		}

		// Skip union logic on recursion.
		if (!recalias && kind != "tkKYW" && !recunion) {
			if (union_) {
				unions.push_back(flg);
				continue;
			} else if (!unions.empty()) {
				for (auto &uflg : unions) {
					uflg.values = values;
					vector<Flag> list {uflg};
					processflags(S, gid, chain, list, queue_flags,
						/*recunion=*/true, /*recalias=*/false);
				}
				unions.clear();
			}
		}

		if (recalias) {
			oContexts[chain]["{" + ltrim(flag, "-") + "|" + alias + "}"] = 1;
			flag = "-" + alias;
		}

		if (kind == "tkKYW") {
			if (!values.empty() && flag != "exclude") {
				string value = "";
				if (values[0].size() == 1) {
					value = regex_replace(tkstr(S, values[0][0]), re_space, "");
					if (flag == "context") value = value.substr(1, value.length() - 2);
				} else {
					value = get_cmdstr(S, values[0][1] + 1, values[0][2]);
				}

				if      (flag == "default") oDefaults[chain][value] = 1;
				else if (flag == "context") oContexts[chain][value] = 1;
				else if (flag == "filedir") oFiledirs[chain][value] = 1;
			}

			continue;
		}

		// Flag with values: build each flag + value.
		if (!values.empty()) {
			// Baseflag: add multi-flag indicator?
			// Add base flag to Set (adds '--flag=' or '--flag=*').
			queue_flags[flag + "=" + (!ismulti.empty() ? "*" : "") ] = 1;
			string mflag = flag + "=" + (!ismulti.empty() ? "" : "*");
			if (hasKey(queue_flags, mflag)) queue_flags.erase(mflag);

			for (auto &value : values) {
				if (value.size() == 1) { // Single
					queue_flags[flag + assignment + tkstr(S, value[0])] = 1;

				} else { // Command-string
					string cmdstr = get_cmdstr(S, value[1] + 1, value[2]);
					queue_flags[flag + assignment + cmdstr] = 1;
				}
			}

		} else {
			if (ismulti.empty()) {
				if (!boolean.empty()) queue_flags[flag + "?"] = 1;
				else if (!assignment.empty()) queue_flags[flag + "="] = 1;
				else queue_flags[flag] = 1;
			} else {
				queue_flags[flag + "=*"] = 1;
				queue_flags[flag + "="] = 1;
			}
		}
	}
}

void populate_keywords(const string &chain) {
	for (auto &kdict : oKeywords) {
		tsl::ordered_map<string, int> orderedmap;
		if (!hasKey(kdict, chain)) kdict[chain] = orderedmap;
	}
}

void populate_chain_flags(StateParse &S, int gid, const string &chain, map<string, int> &container) {
	if (!contains(S.excludes, chain)) {
		processflags(S, gid, chain, ubflags, container,
			/*recunion=*/false, /*recalias=*/false);
	}

	if (!hasKey(oSets, chain)) {
		oSets[chain] = container;
	} else {
		// [https://stackoverflow.com/a/22220891]
		map<string, int> &src_container = oSets[chain];
		for(auto &it : container) {
			src_container[it.first] = it.second;
		}
	}
}

string build_kwstr(const string &kwtype,
		map<string, tsl::ordered_map<string, int>> &container) {

	vector<string> output;

	vector<string> chains;
	for (auto const &it : container) {
		if (it.second.size()) {
			chains.push_back(it.first);
		}
	}
	// chains = mapsort(chains, asort, aobj);

	int cl = chains.size() - 1;
	int i = 0;
	for (auto const &chain : chains) {
		vector<string> values;
		for (auto const &it : container[chain]) {
			values.push_back(it.first);
		}

		string value = (kwtype != "context" ? values.back() :
			"\"" + join(values, ";") + "\"");
		output.push_back(rm_fcmd(chain, re_cmdname) + " " + kwtype + " " + value);
		if (i < cl) output.push_back("\n");
		i++;
	}

	return (!output.empty() ? "\n\n" + join(output, "") : "");
}

vector<string> make_chains(StateParse &S, vector<int> &ccids) {
	vector<string> slots;
	vector<string> chains;
	vector<vector<string>> groups;
	bool grouping = false;

	for (auto const &cid : ccids) {
		if (cid == -1) grouping = !grouping;

		if (!grouping && cid != -1) {
			slots.push_back(tkstr(S, cid));
		} else if (grouping) {
			if (cid == -1) {
				slots.push_back("?");
				vector<string> list;
				groups.push_back(list);
			} else {
				groups.back().push_back(tkstr(S, cid));
			}
		}
	}

	string tstr = join(slots, ".");

	for (auto const &group : groups) {
		if (chains.empty()) {
			for (auto const &command : group) {
				chains.push_back(strreplace(tstr, "?", command));
			}
		} else {
			vector<string> tmp_cmds;
			for (auto const &chain : chains) {
				for (auto const &command : group) {
					tmp_cmds.push_back(strreplace(chain, "?", command));
				}
			}
			chains = tmp_cmds;
		}
	}

	if (groups.empty()) chains.push_back(tstr);

	return chains;
}

tuple <string, string, string, string, string, string, map<string, string>, string>
	acdef(StateParse &S,
		vector<vector<Token>> &branches,
		vector<vector<vector<int>>> &cchains,
		map<int, vector<Flag>> &flags,
		vector<vector<int>> &settings,
		string const &cmdname
	) {

	// Collect all universal block flags.
	// vector<Flag> ubflags;
	for (auto const &ubid : S.ubids) {
		for (auto const &flag : flags[ubid]) {
			ubflags.push_back(flag);
		}
	}

	// Escape '+' chars in commands.
	string rcmdname = regex_replace(cmdname, regex("\\+"), "\\+");
	re_cmdname = regex("^(" + rcmdname + "|[-_a-zA-Z0-9]+)");

	time_t curr_time;
	tm *curr_tm;
	char datestring[100];
	time(&curr_time);
	curr_tm = localtime(&curr_time);
	// [https://www.programiz.com/cpp-programming/library-function/ctime/strftime]
	// [https://www.geeksforgeeks.org/strftime-function-in-c/]
	strftime(datestring, 50, "%a %b %-d %Y %H:%M:%S", curr_tm);
	uint64_t timestamp = timeSinceEpochMillisec();
	// [https://stackoverflow.com/a/2242779]
	// [https://stackoverflow.com/a/26781537]
	// [https://stackoverflow.com/a/5591169]
	// [https://stackoverflow.com/a/24128004]
	string ctime = string(datestring) + " (" + to_string(timestamp) + ")";
	string header = "# DON'T EDIT FILE —— GENERATED: " + ctime + "\n\n";
	if (S.args.test) header = "";

    // Start building acmap contents. -------------------------------------------

	int i = 0;
	for (auto &group : cchains) {
		for (auto &ccids : group) {
        	for (auto const &chain : make_chains(S, ccids)) {
                if (chain == "*") continue;

                map<string, int> container;
                populate_keywords(chain);

				vector<Flag> list;
				if (hasKey(flags, i)) list = flags[i];
				processflags(S, i, chain, list, container,
					/*recunion=*/false, /*recalias=*/false);

                populate_chain_flags(S, i, chain, container);

                // Create missing parent chains.
                // commands = re.split(r'(?<!\\)\.', chain);
                vector<string> commands;
                split(commands, chain, ".");

                commands.pop_back(); // Remove last command (already made).
                for (int l = commands.size() - 1; l > -1; l--) {
                    string rchain = join(commands, "."); // Remainder chain.

                    populate_keywords(rchain);
                    if (!hasKey(oSets, rchain)) {
		                map<string, int> container;
                        populate_chain_flags(S, i, rchain, container);
                    }

                    commands.pop_back(); // Remove last command.
				}
			}
		}
		i++;
	}

    string defaults = build_kwstr("default", oDefaults);
    string filedirs = build_kwstr("filedir", oFiledirs);
    string contexts = build_kwstr("context", oContexts);

    // Populate settings object.
	for (auto const &setting : settings) {
        string name = tkstr(S, setting[0]).substr(1);
        if (name == "test") oTests.push_back(regex_replace(tkstr(S, setting[2]), re_space_cl, ";"));
        else oSettings[name] = (setting.size() > 1) ? tkstr(S, setting[2]) : "";
	}

    // Build settings contents.
    int settings_count = oSettings.size();
    settings_count--;
    for (auto const &it : oSettings) {
        config += "@" + it.first + " = " + it.second;
        if (settings_count) config += "\n";
        settings_count--;
	}

    bool placehold = (hasKey(oSettings, "placehold") && oSettings["placehold"] == "true");
    for (auto const &it : oSets) {
    	// [https://stackoverflow.com/a/9693232]
    	vector<string> keys;
    	for (auto const &itt : it.second) {
			keys.push_back(itt.first);
    	}
    	keys = mapsort(keys, fsort, fobj);
        string flags = join(keys, "|");
        if (flags.empty()) flags = "--";

        // Note: Placehold long flag sets to reduce the file's chars.
        // When flag set is needed its placeholder file can be read.
        if (placehold && flags.length() >= 100) {
            if (!hasKey(omd5Hashes, flags)) {
            	// [http://www.zedwood.com/article/cpp-md5-function]
            	// [https://ofstack.com/C++/20865/c-and-c++-md5-algorithm-implementation-code.html]
                string md5hash = md5(flags).substr(26);
                oPlaceholders[md5hash] = flags;
                omd5Hashes[flags] = md5hash;
                flags = "--p#" + md5hash;
            } else { flags = "--p#" + omd5Hashes[flags]; }
		}

        string row = rm_fcmd(it.first, re_cmdname) + " " + flags;

        // Remove multiple ' --' command chains. Shouldn't be the
        // case but happens when multiple main commands are used.
        if (row == " --" && !has_root) has_root = true;
        else if (row == " --" && has_root) continue;

        acdef_lines.push_back(row);
	}

    // If contents exist, add newline after header.
    string sheader = regex_replace(header, regex("\n$"), "");
    acdef_lines = mapsort(acdef_lines, asort, aobj);
    string acdef_contents = join(acdef_lines, "\n");
    acdef_ = (!acdef_contents.empty()) ? header + acdef_contents : sheader;
    config = (!config.empty()) ? header + config : sheader;

    string tests = "";
    if (!oTests.empty()) {
	    tests = "#!/bin/bash\n\n" + header + "tests=(\n" + join(oTests, "\n") + "\n)";
    }

	string formatted = "";

	tuple <string, string, string, string, string, string, map<string, string>, string> data;
	data = make_tuple(acdef_, config, defaults, filedirs, contexts, formatted, oPlaceholders, tests);

	return data;
}
