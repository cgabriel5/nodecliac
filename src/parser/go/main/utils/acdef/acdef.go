package acdef

import (
	"crypto/md5"
	"encoding/hex"
	"github.com/cgabriel5/compiler/utils/slices"
	"github.com/cgabriel5/compiler/utils/structs"
	"github.com/elliotchance/orderedmap"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

type Flag = structs.Flag
type StateParse = structs.StateParse
type Token = structs.Token

var oSets = make(map[string]map[string]int)
var oDefaults = make(map[string]*orderedmap.OrderedMap)
var oFiledirs = make(map[string]*orderedmap.OrderedMap)
var oContexts = make(map[string]*orderedmap.OrderedMap)

var oKeywords = [3]map[string]*orderedmap.OrderedMap{oDefaults, oFiledirs, oContexts}

var ubflags []Flag

var oSettings = orderedmap.NewOrderedMap()
var settings_count = 0
var oTests []string
var oPlaceholders = make(map[string]string)
var omd5Hashes = make(map[string]string)
var acdef_ = ""
var acdef_lines []string
var config = ""
var defaults = ""
var filedirs = ""
var contexts = ""
var has_root = false

// [https://stackoverflow.com/a/25096729]
var re_cmdname *regexp.Regexp
var re_space = regexp.MustCompile("\\s")
var re_space_cl = regexp.MustCompile(";\\s+")

func tkstr(S *StateParse, tid int) string {
	if tid == -1 {
		return ""
	}
	// Return interpolated string for string tokens.
	tk := &(S.LexerData.Tokens[tid])
	if tk.Kind == "tkSTR" {
		if tk.Str_rep != "" {
			return tk.Str_rep
		}
	}
	start := tk.Start
	end := tk.End
	return S.Text[start : end+1]
}

type Cobj struct {
	i, m      int
	val, orig string
	single    bool
}

func aobj(s string) Cobj {
	return Cobj{
		val: strings.ToLower(s),
	}
}

const C_HYPHEN = '-'

func fobj(s string) Cobj {
	var o = Cobj{
		orig: s,
		val:  strings.ToLower(s),
	}
	// Use if/else as no bool to int conversion.
	if strings.HasSuffix(s, "=*") {
		o.m = 1
	} else {
		o.m = 0
	}
	if s[1] != C_HYPHEN {
		o.orig = s
		o.single = true
	}

	return o
}

func asort(s []Cobj) func(int, int) bool {
	// [https://stackoverflow.com/a/52412444]
	// [https://www.codegrepper.com/code-examples/go/golang+sort+array+of+structs]
	return func(i, j int) bool {
		// Resort to string length.
		result := s[j].val > s[i].val

		// Finally, resort to singleton.
		if !result && s[i].single && s[j].single {
			result = s[i].orig < s[j].orig
		}

		return result
	}
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
func fsort(s []Cobj) func(int, int) bool {
	// [https://stackoverflow.com/a/52412444]
	// [https://www.codegrepper.com/code-examples/go/golang+sort+array+of+structs]
	return func(i, j int) bool {
		// [https://stackoverflow.com/a/16894796]
		// [https://www.cplusplus.com/articles/NhA0RXSz/]
		// [https://stackoverflow.com/a/6771418]
		result := false

		// Give multi-flags precedence.
		if s[i].m == 1 || s[j].m == 1 {
			result = s[j].m < s[i].m
		} else {
			result = asort(s)(i, j)
		}

		return result
	}
}

// Uses map sorting to reduce redundant preprocessing on array items.
//
// @param  {array} A - The source array.
// @param  {function} comp - The comparator function to use.
// @return {array} - The resulted sorted array.
//
// @resource [https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/sort]
// [https://www.codingame.com/playgrounds/15869/c-runnable-snippets/passing-a-function-as-parameter]
func mapsort(A *[]string,
	// [https://golangbyexample.com/func-as-func-argument-go/]
	comp func(s []Cobj) func(int, int) bool,
	comp_obj func(s string) Cobj) []string {

	l := len(*A)

	T := []Cobj{} // Temp array.
	// [https://stackoverflow.com/a/31009108]
	// [https://tour.golang.org/moretypes/13]
	// [https://stackoverflow.com/a/45423692]
	// [https://stackoverflow.com/a/46346226]
	R := make([]string, l, l) // Result array.

	// Short-circuit when source array is empty.
	if l == 0 {
		return R
	}

	var obj Cobj
	i := 0
	for _, a := range *A {
		obj = comp_obj(a)
		obj.i = i
		T = append(T, obj)
		i++
	}
	sort.Slice(T, comp(T))

	for i, val := range T {
		R[i] = (*A)[val.i]
	}
	return R
}

// Removes first command in command chain. However, when command name
// is not the main command in (i.e. in a test file) just remove the
// first command name in the chain.
//
// @param  {string} command - The command chain.
// @return {string} - Modified chain.
func rm_fcmd(chain string, r *regexp.Regexp) string {
	return r.ReplaceAllString(chain, "")
}

func get_cmdstr(S *StateParse, start int, stop int) string {
	var output []string
	var allowed_tk_types = []string{"tkSTR", "tkDLS"}
	for tid := start; tid < stop; tid++ {
		// [TODO] Clean this up.
		if S.LexerData.Tokens[tid].Kind == allowed_tk_types[0] ||
			S.LexerData.Tokens[tid].Kind == allowed_tk_types[1] {
			if len(output) > 0 && output[len(output)-1] == "$" {
				output[len(output)-1] = "$" + tkstr(S, tid)
			} else {
				output = append(output, tkstr(S, tid))
			}
		}
	}
	return "$(" + strings.Join(output, ",") + ")"
}

func processflags(S *StateParse, gid int,
	chain string,
	flags *[]Flag,
	queue_flags *map[string]int,
	recunion bool,
	recalias bool) {

	var unions []Flag
	for _, flg := range *flags {
		tid := flg.Tid
		assignment := tkstr(S, flg.Assignment)
		boolean := tkstr(S, flg.Boolean)
		alias := tkstr(S, flg.Alias)
		flag := tkstr(S, tid)
		ismulti := tkstr(S, flg.Multi)
		union_ := flg.Union_ != -1
		values := &(flg.Values)

		kind := S.LexerData.Tokens[tid].Kind

		if alias != "" && !recalias {
			list := []Flag{flg}
			processflags(S, gid, chain, &list, queue_flags,
				/*recunion=*/ false /*recalias=*/, true)
		}

		// Skip union logic on recursion.
		if !recalias && kind != "tkKYW" && !recunion {
			if union_ {
				unions = append(unions, flg)
				continue
			} else if len(unions) > 0 {
				for _, uflg := range unions {
					uflg.Values = *values
					list := []Flag{uflg}
					processflags(S, gid, chain, &list, queue_flags,
						/*recunion=*/ true /*recalias=*/, false)
				}
				unions = nil
			}
		}

		if recalias {
			oContexts[chain].Set("{"+strings.TrimLeft(flag, "-")+"|"+alias+"}", 1)
			flag = "-" + alias
		}

		if kind == "tkKYW" {
			if len(*values) > 0 && flag != "exclude" {
				value := ""
				if len((*values)[0]) == 1 {
					value = re_space.ReplaceAllString(tkstr(S, (*values)[0][0]), "")
					if flag == "context" {
						value = value[1 : len(value)-2]
					}
				} else {
					value = get_cmdstr(S, (*values)[0][1]+1, (*values)[0][2])
				}

				if flag == "default" {
					oDefaults[chain].Set(value, 1)
				} else if flag == "context" {
					oContexts[chain].Set(value, 1)
				} else if flag == "filedir" {
					oFiledirs[chain].Set(value, 1)
				}
			}

			continue
		}

		// Flag with values: build each flag + value.
		if len(*values) > 0 {
			// Baseflag: add multi-flag indicator?
			// Add base flag to Set (adds '--flag=' or '--flag=*').
			var mflag_ = "*"
			if ismulti == "" {
				mflag_ = ""
			}
			(*queue_flags)[flag+"="+mflag_] = 1

			var mflag_c1 = "*"
			if ismulti != "" {
				mflag_c1 = ""
			}
			mflag := flag + "=" + mflag_c1

			if _, exists := (*queue_flags)[mflag]; exists {
				delete(*queue_flags, mflag)
			}

			for _, value := range *values {
				// for (auto &value : values) {
				if len(value) == 1 { // Single
					(*queue_flags)[flag+assignment+tkstr(S, value[0])] = 1

				} else { // Command-string
					cmdstr := get_cmdstr(S, value[1]+1, value[2])
					(*queue_flags)[flag+assignment+cmdstr] = 1
				}
			}

		} else {
			if ismulti == "" {
				if boolean != "" {
					(*queue_flags)[flag+"?"] = 1
				} else if assignment != "" {
					(*queue_flags)[flag+"="] = 1
				} else {
					(*queue_flags)[flag] = 1
				}
			} else {
				(*queue_flags)[flag+"=*"] = 1
				(*queue_flags)[flag+"="] = 1
			}
		}
	}
}

func populate_keywords(chain string) {
	for _, kdict := range oKeywords {
		if _, exists := kdict[chain]; !exists {
			kdict[chain] = orderedmap.NewOrderedMap()
		}
	}
}

func populate_chain_flags(S *StateParse, gid int, chain string, container *map[string]int) {
	index := slices.Index(len(S.Excludes), func(i int) bool {
		return S.Excludes[i] == chain
	})
	if index == -1 {
		processflags(S, gid, chain, &ubflags, container,
			/*recunion=*/ false /*recalias=*/, false)
	}

	if _, exists := oSets[chain]; !exists {
		oSets[chain] = *container
	} else {
		// [https://stackoverflow.com/a/22220891]
		for key, value := range *container {
			src_container[key] = value
		}
	}
}

func build_kwstr(kwtype string,
	container *map[string]*orderedmap.OrderedMap) string {

	var output []string

	var chains []string
	for key, value := range *container {
		if value.Len() > 0 {
			chains = append(chains, key)
		}
	}
	chains = mapsort(&chains, asort, aobj)

	cl := len(chains) - 1
	i := 0
	for _, chain := range chains {
		var values = []string{}
		// Iterate through all elements from oldest to newest:
		for el := (*container)[chain].Front(); el != nil; el = el.Next() {
			// [https://stackoverflow.com/a/27137607]
			values = append(values, el.Key.(string))
		}

		var value string
		if kwtype != "context" {
			value = values[len(values)-1]
		} else {
			value = "\"" + strings.Join(values, ";") + "\""
		}
		output = append(output, rm_fcmd(chain, re_cmdname)+" "+kwtype+" "+value)
		if i < cl {
			output = append(output, "\n")
		}
		i++
	}

	if len(output) > 0 {
		return "\n\n" + strings.Join(output, "")
	} else {
		return ""
	}
}

func make_chains(S *StateParse, ccids *[]int) []string {
	var slots = []string{}
	var chains = []string{}
	var groups = [][]string{}
	grouping := false

	for _, cid := range *ccids {
		if cid == -1 {
			grouping = !grouping
		}

		if !grouping && cid != -1 {
			slots = append(slots, tkstr(S, cid))
		} else if grouping {
			if cid == -1 {
				slots = append(slots, "?")
				var list = []string{}
				groups = append(groups, list)
			} else {
				groups[len(groups)-1] = append(groups[len(groups)-1], tkstr(S, cid))
			}
		}
	}

	tstr := strings.Join(slots, ".")

	for _, group := range groups {
		if len(chains) == 0 {
			for _, command := range group {
				chains = append(chains, strings.Replace(tstr, "?", command, 1))
			}
		} else {
			var tmp_cmds = []string{}
			for _, chain := range chains {
				for _, command := range group {
					tmp_cmds = append(tmp_cmds, strings.Replace(chain, "?", command, 1))
				}
			}
			chains = tmp_cmds
		}
	}

	if len(groups) == 0 {
		chains = append(chains, tstr)
	}

	return chains
}

func Acdef(S *StateParse,
	branches *[][]Token,
	cchains *[][][]int,
	flags *map[int][]Flag,
	settings *[][]int,
	cmdname string) (string, string, string, string,
		string, string, map[string]string, string) {

	// Collect all universal block flags.
	for _, ubid := range S.Ubids {
		for _, flag := range (*flags)[ubid] {
			ubflags = append(ubflags, flag)
		}
	}

	// Escape '+' chars in commands.
	var re_plussign = regexp.MustCompile("\\+")
	rcmdname := re_plussign.ReplaceAllString(cmdname, "") // [TODO] `replace`
	re_cmdname = regexp.MustCompile("^(" + rcmdname + "|[-_a-zA-Z0-9]+)")

	// [https://yourbasic.org/golang/current-time/]
	// [https://www.golangprograms.com/get-current-date-and-time-in-various-format-in-golang.html]
	now := time.Now()
	timestamp := now.Unix()
	// timestamp_ms := now.UnixNano()
	// [https://yourbasic.org/golang/format-parse-string-time-date-example/]
	datestring := now.Format("Mon Jan 02 2006 15:04:05")
	ctime := datestring + " (" + strconv.Itoa(int(timestamp)) + ")"
	header := "# DON'T EDIT FILE —— GENERATED: " + ctime + "\n\n"
	// if (S.args.test) header = "";

	// Start building acmap contents. -------------------------------------------

	i := 0
	for _, group := range *cchains {
		for _, ccids := range group {
			chains := make_chains(S, &ccids)
			for _, chain := range chains {
				if chain == "*" {
					continue
				}

				var container = make(map[string]int)
				populate_keywords(chain)

				list := []Flag{}
				if _, exists := (*flags)[i]; exists {
					list = (*flags)[i]
				}
				processflags(S, i, chain, &list, &container,
					/*recunion=*/ false /*recalias=*/, false)

				populate_chain_flags(S, i, chain, &container)

				// Create missing parent chains.
				// commands = re.split(r'(?<!\\)\.', chain);
				var commands = strings.Split(chain, ".")

				// [TODO] Check needed?
				if len(commands) > 0 {
					// Remove last command (already made).
					commands = commands[:len(commands)-1]
				}
				var rchain = ""
				for l := len(commands) - 1; l > -1; l-- {
					rchain = strings.Join(commands, ",") // Remainder chain.

					populate_keywords(rchain)
					if _, exists := oSets[rchain]; !exists {
						var container = make(map[string]int)
						populate_chain_flags(S, i, rchain, &container)
					}

					// [TODO] Check needed?
					if len(commands) > 0 {
						// Remove last command.
						commands = commands[:len(commands)-1]
					}
				}
			}
		}
		i++
	}

	defaults := build_kwstr("default", &oDefaults)
	filedirs := build_kwstr("filedir", &oFiledirs)
	contexts := build_kwstr("context", &oContexts)

	// Populate settings object.
	for _, setting := range *settings {
		name := tkstr(S, setting[0])[1:]
		if name == "test" {
			oTests = append(oTests, re_space_cl.ReplaceAllString(tkstr(S, setting[2]), ";"))
		} else {
			if len(setting) > 1 {
				oSettings.Set(name, tkstr(S, setting[2]))
			} else {
				oSettings.Set(name, "")
			}
		}
	}

	// Build settings contents.
	settings_count := oSettings.Len()
	settings_count--
	for el := oSettings.Front(); el != nil; el = el.Next() {
		config += "@" + el.Key.(string) + " = " + el.Value.(string)
		if settings_count > 0 {
			config += "\n"
		}
		settings_count--
	}

	var placehold_val = oSettings.GetOrDefault("placehold", "").(string)
	var placehold = len(placehold_val) > 0 && placehold_val == "true"
	for key, value := range oSets {
		// [https://stackoverflow.com/a/9693232]
		var keys = []string{}
		for key2, _ := range value {
			keys = append(keys, key2)
		}
		keys = mapsort(&keys, fsort, fobj)
		flags := strings.Join(keys, "|")
		if len(flags) == 0 {
			flags = "--"
		}

		// Note: Placehold long flag sets to reduce the file's chars.
		// When flag set is needed its placeholder file can be read.
		if placehold && len(flags) >= 100 {
			if _, exists := omd5Hashes[flags]; !exists {
				// [https://stackoverflow.com/a/25286918]
				hash := md5.Sum([]byte(flags))
				md5hash := hex.EncodeToString(hash[:])[26:]
				oPlaceholders[md5hash] = flags
				omd5Hashes[flags] = md5hash
				flags = "--p#" + md5hash
			} else {
				flags = "--p#" + omd5Hashes[flags]
			}
		}

		row := rm_fcmd(key, re_cmdname) + " " + flags

		// Remove multiple ' --' command chains. Shouldn't be the
		// case but happens when multiple main commands are used.
		if row == " --" && !has_root {
			has_root = true
		} else if row == " --" && has_root {
			continue
		}

		acdef_lines = append(acdef_lines, row)
	}

	// If contents exist, add newline after header.
	re_trailing_nl := regexp.MustCompile("\n$")
	sheader := re_trailing_nl.ReplaceAllString(header, "")
	acdef_lines = mapsort(&acdef_lines, asort, aobj)
	acdef_contents := strings.Join(acdef_lines, "\n")
	if len(acdef_contents) > 0 {
		acdef_ = header + acdef_contents
	} else {
		acdef_ = sheader
	}
	if len(config) > 0 {
		config = header + config
	} else {
		config = sheader
	}

	tests := ""
	if len(oTests) > 0 {
		tests = "#!/bin/bash\n\n" + header + "tests=(\n" + strings.Join(oTests, "\n") + "\n)"
	}

	formatted := ""

	return acdef_, config, defaults, filedirs, contexts, formatted, oPlaceholders, tests
}
