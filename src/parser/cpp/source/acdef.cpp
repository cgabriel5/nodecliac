#include "../headers/structs.hpp"

#include <string>
#include <vector>
#include <map>
#include <set>
#include <regex>
#include <iostream>
#include <ctime>
#include <chrono>
#include <cstdint>
#include <iostream>
#include <algorithm>

using namespace std;

// [https://stackoverflow.com/a/56107709]
uint64_t timeSinceEpochMillisec() {
  using namespace std::chrono;
  return duration_cast<milliseconds>(system_clock::now().time_since_epoch()).count();
}

string tkstr2(LexerResponse &LexerData, const string &text, const int tid) {
	if (tid == -1) return "";
	if (LexerData.tokens[tid].kind == "tkSTR") {
		if (!LexerData.tokens[tid].$.empty()) return LexerData.tokens[tid].$;
	}
	int start = LexerData.tokens[tid].start;
	int end = LexerData.tokens[tid].end;
	return text.substr(start, end - start + 1);
}

// [https://stackoverflow.com/a/2072890]
inline bool endswith2(string const &value, string const &ending) {
	if (ending.size() > value.size()) return false;
	return equal(ending.rbegin(), ending.rend(), value.rbegin());
}

struct Cobj {
    int i, m;
    string val, orig;
    bool single;
};

Cobj aobj(string s) {
	// [https://stackoverflow.com/a/3403868]
	transform(s.begin(), s.end(), s.begin(), ::tolower);
    Cobj o;
    o.val = s;
    return o;
}

bool asort(const Cobj &a, const Cobj &b) {
	int result = 0;

    if (a.val != b.val) {
        if (a.val < b.val) result = -1;
        else result = 1;
    } else { result = 0; }

    if (result == 0 && a.single and b.single) {
        if (a.orig < b.orig) result = 1;
        else result = 0;
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
    int result = b.m - a.m;
    if (result == 0) result = asort(a, b);
    return result;
}

const char C_HYPHEN = '-';

Cobj fobj(string s) {
    Cobj o;
    o.orig = s;
    o.val = s;
	transform(o.val.begin(), o.val.end(), o.val.begin(), ::tolower);
    o.m = endswith2(s, "=*");
    if (s[1] != C_HYPHEN) {
        o.orig = s;
        o.single = true;
    }
    return o;
}

// Uses map sorting to reduce redundant preprocessing on array items.
//
// @param  {array} A - The source array.
// @param  {function} comp - The comparator function to use.
// @return {array} - The resulted sorted array.
//
// @resource [https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/sort]
vector<string> mapsort(vector<string> &A,
		bool (*comp)(const Cobj &a, const Cobj &b),
		const string &cobj_type) {

	vector<Cobj> T; // Temp array.
	vector<string> R; // Result array.
	R.reserve(A.size());
	Cobj obj;
	int i = 0;
	for (auto const &a : A) {
		if (cobj_type == "aobj") obj = aobj(a);
		else obj = fobj(a);
		obj.i = i;
		T.push_back(obj);
		i++;
	}
	sort(T.begin(), T.end(), comp);
	i = 0;
	for (auto const &item : T) {
		R[i] = A[T[i].i];
	}
	return R;
}

void acdef(vector<vector<Token>> &branches,
		vector<vector<vector<int>>> &cchains,
		map<int, vector<Flag>> &flags,
		vector<vector<int>> &settings,
		StateParse &S,
		LexerResponse &LexerData,
		string const &cmdname
	) {

    vector<int> &ubids = S.ubids;
    string &text = S.text;
    vector<Token> &tokens = LexerData.tokens;
    vector<string> &excludes = S.excludes;

    map<string, map<string, int>> oSets;
    map<string, set<string>> oDefaults;
    map<string, set<string>> oFiledirs;
    map<string, set<string>> oContexts;

    map<string, string> oSettings;
    int settings_count = 0;
    vector<string> oTests;
    map<string, string> oPlaceholders;
    map<string, string> omd5Hashes;
    string acdef = "";
    vector<string> acdef_lines;
    string config = "";
    string defaults = "";
    string filedirs = "";
    string contexts = "";
    bool has_root = false;

    // __locals__ = locals()

    // Collect all universal block flags.
	vector<Flag> ubflags;
	for (auto const &ubid : ubids) {
		for (auto const &flag : flags[ubid]) {
			ubflags.push_back(flag);
		}
	}
    vector<map<string, set<string>>> oKeywords {oDefaults, oFiledirs, oContexts};

	// Escape '+' chars in commands.
	string rcmdname = regex_replace(cmdname, regex("\\+"), "\\+");
	regex r("^(" + rcmdname + "|[-_a-zA-Z0-9]+)");

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
    cout << header << endl;
    // if S["args"]["test"]: header = ""

    // // Removes first command in command chain. However, when command name
    // // is not the main command in (i.e. in a test file) just remove the
    // // first command name in the chain.
    // #
    // // @param  {string} command - The command chain.
    // // @return {string} - Modified chain.
    // def rm_fcmd(chain):
    //     return re.sub(r, "", chain)

    // def get_cmdstr(start, stop):
    //     output = []
    //     allowed_tk_types = ("tkSTR", "tkDLS")
    //     for tid in range(start, stop):
    //         if S["tokens"][tid]["kind"] in allowed_tk_types:
    //             if output and output[-1] == "$": output[-1] = "$" + tkstr(tid)
    //             else: output.append(tkstr(tid))

    //     return "$({})".format(",".join(output))

    // def processflags(gid, chain, flags, queue_flags, recunion=False, recalias=False):
    //     unions = []
    //     for flg in flags:
    //         tid = flg["tid"]
    //         assignment = tkstr(flg["assignment"])
    //         boolean = tkstr(flg["boolean"])
    //         alias = tkstr(flg["alias"])
    //         flag = tkstr(tid)
    //         ismulti = tkstr(flg["multi"])
    //         union = flg["union"] != -1
    //         values = flg["values"]
    //         kind = tokens[tid]["kind"]

    //         if alias and not recalias:
    //             processflags(gid, chain, [flg], queue_flags, recalias=True)

    //         // Skip union logic on recursion.
    //         if not recalias and kind != "tkKYW" and not recunion:
    //             if union:
    //                 unions.append(flg)
    //                 continue
    //             elif unions:
    //                 for uflg in unions:
    //                     uflg["values"] = values
    //                     processflags(gid, chain, [uflg], queue_flags, recunion=True)
    //                 unions.clear()

    //         if recalias:
    //             oContexts[chain][f"{{{flag.strip('-')}|{alias}}}"] = 1
    //             flag = "-" + alias

    //         if kind == "tkKYW":
    //             if values and flag != "exclude":
    //                 if len(values[0]) == 1:
    //                     value = re.sub(r"\s", "", tkstr(values[0][0]))
    //                     if flag == "context": value = value[1:-1]
    //                 else:
    //                     value = get_cmdstr(values[0][1] + 1, values[0][2])

    //                 __locals__[f"o{flag.capitalize()}s"][chain][value] = 1

    //             continue

    //         // Flag with values: build each flag + value.
    //         if values:
    //             // Baseflag: add multi-flag indicator?
    //             // Add base flag to Set (adds '--flag=' or '--flag=*').
    //             queue_flags[f"{flag}={'*' if ismulti else ''}"] = 1
    //             mflag = f"{flag}={'' if ismulti else '*'}"
    //             if mflag in queue_flags: del queue_flags[mflag]

    //             for value in values:
    //                 if len(value) == 1: // Single
    //                     queue_flags[flag + assignment + tkstr(value[0])] = 1

    //                 else: // Command-string
    //                     cmdstr = get_cmdstr(value[1] + 1, value[2])
    //                     queue_flags[flag + assignment + cmdstr] = 1

    //         else:
    //             if not ismulti:
    //                 if boolean: queue_flags[flag + "?"] = 1
    //                 elif assignment: queue_flags[flag + "="] = 1
    //                 else: queue_flags[flag] = 1
    //             else:
    //                 queue_flags[flag + "=*"] = 1
    //                 queue_flags[flag + "="] = 1

    // def populate_keywords(chain):
    //     for kdict in oKeywords:
    //         if chain not in kdict: kdict[chain] = OrderedDict()

    // def populate_chain_flags(gid, chain, container):
    //     if chain not in excludes:
    //         processflags(gid, chain, ubflags, container)

    //     if chain not in oSets:
    //         oSets[chain] = container
    //     else:
    //         oSets[chain].update(container)

    // def build_kwstr(kwtype, container):
    //     output = []
    //     chains = mapsort([c for c in container if container[c]], asort, aobj)
    //     cl = len(chains) - 1
    //     tstr = "{} {} {}"
    //     for i, chain in enumerate(chains):
    //         values = list(container[chain])
    //         value = (values[-1] if kwtype != "context"
    //             else "\"" + ";".join(values) + "\"")
    //         output.append(tstr.format(rm_fcmd(chain), kwtype, value))
    //         if i < cl: output.append("\n")

    //     return "\n\n" + "".join(output) if output else ""

    // def make_chains(ccids):
    //     slots = []
    //     chains = []
    //     groups = []
    //     grouping = False

    //     for cid in ccids:
    //         if cid == -1: grouping = not grouping

    //         if not grouping and cid != -1:
    //             slots.append(tkstr(cid))
    //         elif grouping:
    //             if cid == -1:
    //                 slots.append('?')
    //                 groups.append([])
    //             else: groups[-1].append(tkstr(cid))

    //     tstr = ".".join(slots)

    //     for group in groups:
    //         if not chains:
    //             for command in group:
    //                 chains.append(tstr.replace('?', command, 1))
    //         else:
    //             tmp_cmds = []
    //             for chain in chains:
    //                 for command in group:
    //                     tmp_cmds.append(chain.replace('?', command))
    //             chains = tmp_cmds

    //     if not groups: chains.append(tstr)

    //     return chains

    // // Start building acmap contents. -------------------------------------------

    // for i, group in enumerate(cchains):
    //     for ccids in group:
    //         for chain in make_chains(ccids):
    //             if chain == "*": continue

    //             container = {}
    //             populate_keywords(chain)
    //             processflags(i, chain, flags.get(i, []), container)
    //             populate_chain_flags(i, chain, container)

    //             // Create missing parent chains.
    //             commands = re.split(r'(?<!\\)\.', chain)
    //             commands.pop() // Remove last command (already made).
    //             for _ in range(len(commands) - 1, -1, -1):
    //                 rchain = ".".join(commands) // Remainder chain.

    //                 populate_keywords(rchain)
    //                 if rchain not in oSets:
    //                     populate_chain_flags(i, rchain, {})

    //                 commands.pop() // Remove last command.

    // defaults = build_kwstr("default", oDefaults)
    // filedirs = build_kwstr("filedir", oFiledirs)
    // contexts = build_kwstr("context", oContexts)

    // // Populate settings object.
    // for setting in settings:
    //     name = tkstr(setting[0])[1:]
    //     if name == "test": oTests.append(re.sub(r";\s+", ";", tkstr(setting[2])))
    //     else: oSettings[name] = tkstr(setting[2]) if len(setting) > 1 else ""

    // // Build settings contents.
    // settings_count = len(oSettings)
    // settings_count -= 1
    // for setting in oSettings:
    //     config += f"@{setting} = {oSettings[setting]}"
    //     if settings_count: config += "\n"
    //     settings_count -= 1

    // placehold = "placehold" in oSettings and oSettings["placehold"] == "true"
    // for key in oSets:
    //     flags = "|".join(mapsort(list(oSets[key].keys()), fsort, fobj))
    //     if not flags: flags = "--"

    //     // Note: Placehold long flag sets to reduce the file's chars.
    //     // When flag set is needed its placeholder file can be read.
    //     if placehold and len(flags) >= 100:
    //         if flags not in omd5Hashes:
    //             // [https://stackoverflow.com/a/65613163]
    //             md5hash = hashlib.md5(flags.encode()).hexdigest()[26:]
    //             oPlaceholders[md5hash] = flags
    //             omd5Hashes[flags] = md5hash
    //             flags = "--p#" + md5hash
    //         else: flags = "--p#" + omd5Hashes[flags]

    //     row = f"{rm_fcmd(key)} {flags}"

    //     // Remove multiple ' --' command chains. Shouldn't be the
    //     // case but happens when multiple main commands are used.
    //     if row == " --" and not has_root: has_root = True
    //     elif row == " --" and has_root: continue

    //     acdef_lines.append(row)

    // // If contents exist, add newline after header.
    // sheader = re.sub(r"\n$", "", header)
    // acdef_contents = "\n".join(mapsort(acdef_lines, asort, aobj))
    // acdef = header + acdef_contents if acdef_contents else sheader
    // config = header + config if config else sheader

    // tests_tstr = "#!/bin/bash\n\n{}tests=(\n{}\n)"
    // tests = tests_tstr.format(header, "\n".join(oTests)) if oTests else ""

    // return (
    //     acdef,
    //     config,
    //     defaults,
    //     filedirs,
    //     contexts,
    //     "", // formatted
    //     oPlaceholders,
    //     tests
    // )
}
