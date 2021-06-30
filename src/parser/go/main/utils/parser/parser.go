package parser

import (
	"github.com/cgabriel5/compiler/utils/defvars"
	"github.com/cgabriel5/compiler/utils/issue"
	"github.com/cgabriel5/compiler/utils/lexer"
	"github.com/cgabriel5/compiler/utils/slices"
	"github.com/cgabriel5/compiler/utils/structs"
	"github.com/cgabriel5/compiler/utils/validation"
	"k8s.io/apimachinery/pkg/util/sets"
	"regexp"
	"sort"
	"strings"
)

type TabData = structs.TabData
type Token = structs.Token
type StateParse = structs.StateParse
type Flag = structs.Flag
type Warning = structs.Warning

// [https://stackoverflow.com/a/25096729]
var r = regexp.MustCompile(`(^|[^\\])(\$\{\s*[^}]*\s*\})`)

var tkTYPES_1 = []string{"tkSTN", "tkVAR", "tkCMD"}
var tkTYPES_2 = []string{"tkFLG", "tkKYW"}
var tkTYPES_3 = []string{"tkFLG", "tkKYW"}

var S = StateParse{}

var ttid = 0
var NEXT []string
var SCOPE []string
var branch []Token
var BRANCHES = [][]Token{} // [https://www.dotnetperls.com/2d-go]
var oneliner = -1

var chain []int
var CCHAINS = [][][]int{}

var FLAGS = map[int][]Flag{}
var flag = Flag{}

var setting []int
var SETTINGS = [][]int{}

var variable []int
var VARIABLES = [][]int{}

var USED_VARS = make(map[string]int)
var USER_VARS = make(map[string][]int)
var VARSTABLE = make(map[string]string) // = builtins(cmdname)
// [https://stackoverflow.com/a/15178302]
var vindices = make(map[int][][]int)

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

func err(S *StateParse, tid int, message string, pos string, scope string) {
	// When token ID points to end-of-parsing token,
	// reset the id to the last true token before it.
	if S.LexerData.Tokens[tid].Kind == "tkEOP" {
		tid = S.LexerData.Ttids[len(S.LexerData.Ttids)-1]
	}

	token := &(S.LexerData.Tokens[tid])
	line := token.Line
	var index int
	if pos == "start" {
		index = token.Start
	} else {
		index = token.End
	}
	col := index - S.LexerData.LINESTARTS[line]

	if strings.HasSuffix(message, ":") {
		message += " '" + tkstr(S, tid) + "'"
	}

	// Add token debug information.
	// dbeugmsg = "\n\n\033[1mToken\033[0m: "
	// dbeugmsg += "\n - tid: " + str(token["tid"])
	// dbeugmsg += "\n - kind: " + token["kind"]
	// dbeugmsg += "\n - line: " + str(token["line"])
	// dbeugmsg += "\n - start: " + str(token["start"])
	// dbeugmsg += "\n - end: " + str(token["end"])
	// dbeugmsg += "\n __val__: [" + tkstr(tid) + "]"

	// dbeugmsg += "\n\n\033[1mExpected\033[0m: "
	// for n in NEXT:
	//     if not n: n = "\"\""
	//     dbeugmsg += "\n - " + n
	// dbeugmsg += "\n\n\033[1mScopes\033[0m: "
	// for s in SCOPE:
	//     dbeugmsg += "\n - " + s
	// decor = "-" * 15
	// msg += "\n\n" + decor + " TOKEN_DEBUG_INFO " + decor
	// msg += dbeugmsg
	// msg += "\n\n" + decor + " TOKEN_DEBUG_INFO " + decor

	issue.Issue_error(S.Filename, line, col, message)
}

func warn(S *StateParse, tid int, message string) {
	token := &(S.LexerData.Tokens[tid])
	line := token.Line
	index := token.Start
	col := index - S.LexerData.LINESTARTS[line]

	if strings.HasSuffix(message, ":") {
		message += " '" + tkstr(S, tid) + "'"
	}

	if _, exists := S.Warnings[line]; !exists {
		S.Warnings[line] = []Warning{}
	}

	var warning = Warning{
		Filename: S.Filename,
		Line:     line,
		Column:   col,
		Message:  message,
	}

	S.Warnings[line] = append(S.Warnings[line], warning)
	S.Warn_lines.Insert(line)
}

func hint(S *StateParse, tid int, message string) {
	token := &(S.LexerData.Tokens[tid])
	line := token.Line
	index := token.Start
	col := index - S.LexerData.LINESTARTS[line]

	if strings.HasSuffix(message, ":") {
		message += " '" + tkstr(S, tid) + "'"
	}

	issue.Issue_hint(S.Filename, line, col, message)
}

func addtoken(S *StateParse, i int) {
	// Interpolate/track interpolation indices for string.
	if S.LexerData.Tokens[i].Kind == "tkSTR" {
		value := tkstr(S, i)
		S.LexerData.Tokens[i].Str_rep = value

		if _, exists := vindices[i]; !exists {
			end_ := 0
			pointer := 0
			tmpstr := ""

			vindices[i] = [][]int{}

			// [https://stackoverflow.com/a/43795154]
			// [https://stackoverflow.com/q/31976346]
			matches := r.FindAllStringIndex(value, -1)
			for _, match := range matches {
				start := match[0] + 1
				end_ := match[1]
				varname := strings.TrimSpace(value[start+2 : end_-1])

				if _, exists := VARSTABLE[varname]; !exists {
					// Note: Modify token index to point to
					// start of the variable position.
					S.LexerData.Tokens[S.Tid].Start += start
					err(S, ttid, "Undefined variable", "start", "child")
				}

				USED_VARS[varname] = 1
				vindices[i] = append(vindices[i], []int{start, end_})

				tmpstr += value[pointer:start]
				sub, _ := VARSTABLE[varname]
				if sub != "" {
					if sub[0] != '"' || sub[1] != '\'' {
						tmpstr += sub
					} else {
						// Unquote string if quoted.
						tmpstr += sub[1 : len(sub)-2]
					}
				}
				pointer = end_
			}

			// Get tail-end of string.
			tmpstr += value[:end_]
			S.LexerData.Tokens[i].Str_rep = tmpstr

			if len(vindices[i]) == 0 {
				delete(vindices, i)
			}
		}
	}

	BRANCHES[len(BRANCHES)-1] = append(BRANCHES[len(BRANCHES)-1], S.LexerData.Tokens[i])
}

func expect(list *[]string) {
	NEXT = nil // [https://yourbasic.org/golang/clear-slice/]
	NEXT = *list
}

func clearscope() {
	SCOPE = nil
}

func addscope(s string) {
	SCOPE = append(SCOPE, s)
}

func popscope(pops int) {
	for pops > 0 {
		// [https://stackoverflow.com/a/26172328]
		SCOPE = SCOPE[:len(SCOPE)-1]
		pops -= 1
	}
}

func hasscope(s string) bool {
	return slices.Contains(SCOPE, s)
}

func prevscope() string {
	return SCOPE[len(SCOPE)-1]
}

func hasnext(s string) bool {
	return slices.Contains(NEXT, s)
}

func nextany() bool {
	return NEXT[0] == ""
}

func addbranch() {
	BRANCHES = append(BRANCHES, branch)
}

func newbranch() {
	branch = []Token{}
}

func prevtoken(S *StateParse) *Token {
	return &(S.LexerData.Tokens[S.LexerData.Dtids[S.Tid]])
}

// Command chain/flag grouping helpers.
// ================================

func newgroup() {
	chain = []int{}
}

func addtoken_group(i int) {
	lchain := &CCHAINS[len(CCHAINS)-1]
	lgroup := &(*lchain)[len(*lchain)-1] // Last branch token.
	*lgroup = append(*lgroup, i)
}

func addgroup(g *[]int) {
	g_ := [][]int{}
	g_ = append(g_, *g)
	CCHAINS = append(CCHAINS, g_)
}

func addtoprevgroup() {
	newgroup()
	lchain := &CCHAINS[len(CCHAINS)-1]
	*lchain = append(*lchain, chain)
}

// ============================

func newvaluegroup(prop string) {
	index := len(CCHAINS) - 1
	lflag := &(FLAGS[index][len(FLAGS[index])-1])
	values := &(lflag.Values)
	*values = append(*values, []int{-1})
}

func setflagprop(prop string, prev_val_group bool) {
	index := len(CCHAINS) - 1
	lflag := &(FLAGS[index][len(FLAGS[index])-1])

	if prop != "values" {
		if prop == "tid" {
			lflag.Tid = S.Tid
		} else if prop == "alias" {
			lflag.Alias = S.Tid
		} else if prop == "boolean" {
			lflag.Boolean = S.Tid
		} else if prop == "assignment" {
			lflag.Assignment = S.Tid
		} else if prop == "multi" {
			lflag.Multi = S.Tid
		} else if prop == "union" {
			lflag.Union_ = S.Tid
		}
	} else {
		values := &(lflag.Values)

		if !prev_val_group {
			*values = append(*values, []int{S.Tid})
		} else {
			lval := &(*values)[len(*values)-1]
			*lval = append(*lval, S.Tid)
		}
	}
}

func newflag() {
	var flag = Flag{
		Tid:        -1,
		Alias:      -1,
		Boolean:    -1,
		Assignment: -1,
		Multi:      -1,
		Union_:     -1,
	}

	index := len(CCHAINS) - 1
	if _, exists := FLAGS[index]; !exists {
		FLAGS[index] = []Flag{}
	}
	FLAGS[index] = append(FLAGS[index], flag)
	setflagprop("tid", false)
}

// Setting/variable grouping helpers.
// ================================

func newgroup_stn() {
	setting = []int{}
}

func addtoken_stn_group(i int) {
	lentry := &SETTINGS[len(SETTINGS)-1]
	*lentry = append(*lentry, i)
}

func addgroup_stn(g *[]int) {
	SETTINGS = append(SETTINGS, *g)
}

// void addtoprevgroup_stn() {
// 	newgroup_stn()
// 	SETTINGS.back().push_back(setting)
// }

// ============================

func newgroup_var() {
	variable = []int{}
}

func addtoken_var_group(i int) {
	lentry := &VARIABLES[len(VARIABLES)-1]
	*lentry = append(*lentry, i)
}

func addgroup_var(g *[]int) {
	VARIABLES = append(VARIABLES, *g)
}

// void addtoprevgroup_var() {
// 	newgroup_var()
// 	VARIABLES.back().push_back(variable)
// }

// ============================

func Parser(action, text, cmdname, source string, fmtinfo TabData, trace, igc, test bool) {

	// [https://gist.github.com/shockalotti/6cbfc0aee8825bad168a]
	S.Text = text
	S.Filename = source
	S.Args.Action = action
	S.Args.Source = source
	S.Args.Fmt = fmtinfo
	S.Args.Trace = trace
	S.Args.Igc = igc
	S.Args.Test = test

	tokens, ttypes, ttids, dtids, LINESTARTS := lexer.Tokenizer(text)

	S.LexerData.Tokens = tokens
	S.LexerData.Ttypes = ttypes
	S.LexerData.Ttids = ttids
	S.LexerData.Dtids = dtids
	S.LexerData.LINESTARTS = LINESTARTS

	// [https://medium.com/@KeithAlpichi/go-gotcha-nil-maps-66b851c50475]
	S.Warnings = make(map[int][]Warning)
	// [https://play.golang.org/p/c0QmcLhxKk4]
	S.Warn_lines = make(sets.Int)
	S.Warn_lsort = make(sets.Int)

	// Add builtin variables to variable table.
	for key, value := range defvars.Builtins(cmdname) {
		VARSTABLE[key] = value
	}

	// =========================================================================

	i := 0
	l := len(tokens)

	for i < l {
		token := &tokens[i]
		kind := token.Kind
		line := token.Line
		// start := token.Start
		// end := token.End
		S.Tid = token.Tid

		if kind == "tkNL" {
			i += 1
			continue
		}

		if kind != "tkEOP" {
			ttid = i
		}

		if kind == "tkTRM" {
			if len(SCOPE) == 0 {
				addbranch()
				addtoken(&S, ttid)
				newbranch()
				list := []string{""}
				expect(&list)
			} else {
				addtoken(&S, ttid)

				if len(NEXT) > 0 && !nextany() {
					err(&S, ttid, "Improper termination", "start", "child")
				}
			}

			i += 1
			continue
		}

		if len(SCOPE) == 0 {

			oneliner = -1

			if len(BRANCHES) > 0 {
				lbranch := &BRANCHES[len(BRANCHES)-1]
				ltoken := (*lbranch)[len(*lbranch)-1] // Last branch token.
				if line == ltoken.Line && ltoken.Kind != "tkTRM" {
					err(&S, ttid, "Improper termination", "start", "parent")
				}
			}

			if kind != "tkEOP" {
				addbranch()
				addtoken(&S, ttid)
			}

			if kind != "tkEOP" {
				if slices.Contains(tkTYPES_1, kind) {
					addscope(kind)
					if kind == "tkSTN" {
						newgroup_stn()
						addgroup_stn(&setting)
						addtoken_stn_group(S.Tid)

						validation.Vsetting(&S)
						list := []string{"", "tkASG"}
						expect(&list)
					} else if kind == "tkVAR" {
						newgroup_var()
						addgroup_var(&variable)
						addtoken_var_group(S.Tid)

						varname := tkstr(&S, S.Tid)[1:]
						VARSTABLE[varname] = ""

						if _, exists := USER_VARS[varname]; !exists {
							USER_VARS[varname] = []int{}
						}
						USER_VARS[varname] = append(USER_VARS[varname], S.Tid)

						validation.Vvariable(&S)
						list := []string{"", "tkASG"}
						expect(&list)
					} else if kind == "tkCMD" {
						addgroup(&chain)
						addtoken_group(S.Tid)

						list := []string{"", "tkDDOT", "tkASG", "tkDCMA"}
						expect(&list)

						command := tkstr(&S, S.Tid)
						if command != "*" && command != cmdname {
							warn(&S, S.Tid, "Unexpected command:")
						}
					}
				} else {
					if kind == "tkCMT" {
						newbranch()
						list := []string{""}
						expect(&list)
					} else { // Handle unexpected parent tokens.
						err(&S, S.Tid, "Unexpected token:", "start", "parent")
					}
				}
			}

		} else {

			if kind == "tkCMT" {
				addtoken(&S, ttid)
				i += 1
				continue
			}

			// Remove/add necessary tokens when parsing long flag form.
			if hasscope("tkBRC_LB") {
				if hasnext("tkDPPE") {
					// [https://stackoverflow.com/a/18203895]
					index := slices.Index(len(NEXT), func(i int) bool {
						return NEXT[i] == "tkDPPE"
					})
					// [https://stackoverflow.com/a/63735707]
					if index > -1 {
						NEXT = append(NEXT[:index], NEXT[index+1:]...)
					}
					NEXT = append(NEXT, "tkFLG", "tkKYW", "tkBRC_RB")
				}
			}

			if len(NEXT) > 0 && !hasnext(kind) {
				if nextany() {
					clearscope()
					newbranch()

					newgroup()
					continue

				} else {
					err(&S, S.Tid, "Unexpected token:", "start", "child")
				}
			}

			addtoken(&S, ttid)

			// Oneliners must be declared on oneline, else error.
			if BRANCHES[len(BRANCHES)-1][0].Kind == "tkCMD" &&
				(((hasscope("tkFLG") || hasscope("tkKYW")) ||
					slices.Contains(tkTYPES_2, kind)) &&
					!hasscope("tkBRC_LB")) {
				if oneliner == -1 {
					oneliner = token.Line
				} else if token.Line != oneliner {
					err(&S, S.Tid, "Improper oneliner", "start", "child")
				}
			}

			switch prevscope() {
			case "tkSTN":
				switch kind {
				case "tkASG":
					{
						addtoken_stn_group(S.Tid)

						list := []string{"tkSTR", "tkAVAL"}
						expect(&list)
					}
				case "tkSTR":
					{
						addtoken_stn_group(S.Tid)

						list := []string{""}
						expect(&list)

						validation.Vstring(&S)
					}
				case "tkAVAL":
					{
						addtoken_stn_group(S.Tid)

						list := []string{""}
						expect(&list)

						validation.Vsetting_aval(&S)
					}
				}
			case "tkVAR":
				switch kind {
				case "tkASG":
					{
						addtoken_var_group(S.Tid)

						list := []string{"tkSTR"}
						expect(&list)

					}
				case "tkSTR":
					{
						addtoken_var_group(S.Tid)
						lbranch := &BRANCHES[len(BRANCHES)-1] // Last branch token.
						size := len(*lbranch)
						VARSTABLE[tkstr(&S, (*lbranch)[size-3].Tid)[1:]] = tkstr(&S, S.Tid)

						list := []string{""}
						expect(&list)

						validation.Vstring(&S)
					}
				}

			case "tkCMD":
				switch kind {
				case "tkASG":
					{
						// If a universal block, store group id.
						if _, exists := S.LexerData.Dtids[S.Tid]; exists {
							prevtk := prevtoken(&S)
							if prevtk.Kind == "tkCMD" && S.Text[prevtk.Start] == '*' {
								S.Ubids = append(S.Ubids, len(CCHAINS)-1)
							}
						}
						list := []string{"tkBRC_LB", "tkFLG", "tkKYW"}
						expect(&list)
					}
				case "tkBRC_LB":
					{
						addscope(kind)
						list := []string{"tkFLG", "tkKYW", "tkBRC_RB"}
						expect(&list)
					}
				// // [TODO] Pathway needed?
				// case "tkBRC_RB": {
				// 	list := []string{"", "tkCMD"}
				// 	expect(&list)
				//
				// }
				case "tkFLG":
					{
						newflag()

						addscope(kind)
						list := []string{"", "tkASG", "tkQMK", "tkDCLN", "tkFVAL", "tkDPPE", "tkBRC_RB"}
						expect(&list)
					}
				case "tkKYW":
					{
						newflag()

						addscope(kind)
						list := []string{"tkSTR", "tkDLS"}
						expect(&list)
					}
				case "tkDDOT":
					{
						list := []string{"tkCMD", "tkBRC_LC"}
						expect(&list)
					}
				case "tkCMD":
					{
						addtoken_group(S.Tid)

						list := []string{"", "tkDDOT", "tkASG", "tkDCMA"}
						expect(&list)
					}
				case "tkBRC_LC":
					{
						addtoken_group(-1)

						addscope(kind)
						list := []string{"tkCMD"}
						expect(&list)
					}
				case "tkDCMA":
					{
						// If a universal block, store group id.
						if _, exists := S.LexerData.Dtids[S.Tid]; exists {
							prevtk := prevtoken(&S)
							if prevtk.Kind == "tkCMD" && S.Text[prevtk.Start] == '*' {
								S.Ubids = append(S.Ubids, len(CCHAINS)-1)
							}
						}

						addtoprevgroup()

						addscope(kind)
						list := []string{"tkCMD"}
						expect(&list)
					}
				}

			case "tkBRC_LC":
				switch kind {
				case "tkCMD":
					{
						addtoken_group(S.Tid)

						list := []string{"tkDCMA", "tkBRC_RC"}
						expect(&list)
					}
				case "tkDCMA":
					{
						list := []string{"tkCMD"}
						expect(&list)
					}
				case "tkBRC_RC":
					{
						addtoken_group(-1)

						popscope(1)
						list := []string{"", "tkDDOT", "tkASG", "tkDCMA"}
						expect(&list)
					}
				}

			case "tkFLG":
				switch kind {
				case "tkDCLN":
					{
						if prevtoken(&S).Kind != "tkDCLN" {
							list := []string{"tkDCLN"}
							expect(&list)
						} else {
							list := []string{"tkFLGA"}
							expect(&list)
						}
					}
				case "tkFLGA":
					{
						setflagprop("alias", false)

						list := []string{"", "tkASG", "tkQMK", "tkDPPE"}
						expect(&list)
					}
				case "tkQMK":
					{
						setflagprop("boolean", false)

						list := []string{"", "tkDPPE"}
						expect(&list)
					}
				case "tkASG":
					{
						setflagprop("assignment", false)

						list := []string{"", "tkDCMA", "tkMTL", "tkDPPE", "tkBRC_LP",
							"tkFVAL", "tkSTR", "tkDLS", "tkBRC_RB"}
						expect(&list)
					}
				case "tkDCMA":
					{
						setflagprop("union", false)

						list := []string{"tkFLG", "tkKYW"}
						expect(&list)
					}
				case "tkMTL":
					{
						setflagprop("multi", false)

						list := []string{"", "tkBRC_LP", "tkDPPE"}
						expect(&list)
					}
				case "tkDLS":
					{
						addscope(kind) // Build cmd-string.
						list := []string{"tkBRC_LP"}
						expect(&list)
					}
				case "tkBRC_LP":
					{
						addscope(kind)
						list := []string{"tkFVAL", "tkSTR", "tkFOPT", "tkDLS", "tkBRC_RP"}
						expect(&list)
					}
				case "tkFLG":
					{
						newflag()

						if hasscope("tkBRC_LB") && token.Line == prevtoken(&S).Line {
							err(&S, S.Tid, "Flag same line (nth)", "start", "child")
						}
						list := []string{"", "tkASG", "tkQMK",
							"tkDCLN", "tkFVAL", "tkDPPE"}
						expect(&list)
					}
				case "tkKYW":
					{
						newflag()

						// [TODO] Investigate why leaving flag scope doesn't affect
						// parsing. For now remove it to keep scopes array clean.
						popscope(1)

						if hasscope("tkBRC_LB") && token.Line == prevtoken(&S).Line {
							err(&S, S.Tid, "Keyword same line (nth)", "start", "child")
						}
						addscope(kind)
						list := []string{"tkSTR", "tkDLS"}
						expect(&list)
					}
				case "tkSTR":
					{
						setflagprop("values", false)

						list := []string{"", "tkDPPE"}
						expect(&list)
					}
				case "tkFVAL":
					{
						setflagprop("values", false)

						list := []string{"", "tkDPPE"}
						expect(&list)
					}
				case "tkDPPE":
					{
						list := []string{"tkFLG", "tkKYW"}
						expect(&list)

					}
				case "tkBRC_RB":
					{
						popscope(1)
						list := []string{""}
						expect(&list)
					}
				}

			case "tkBRC_LP":
				switch kind {
				case "tkFOPT":
					{
						prevtk := prevtoken(&S)
						if prevtk.Kind == "tkBRC_LP" {
							if prevtk.Line == line {
								err(&S, S.Tid, "Option same line (first)", "start", "child")
							}
							addscope("tkOPTS")
							list := []string{"tkFVAL", "tkSTR", "tkDLS"}
							expect(&list)
						}
					}
				case "tkFVAL":
					{
						setflagprop("values", false)

						list := []string{"tkFVAL", "tkSTR", "tkDLS", "tkBRC_RP", "tkTBD"}
						expect(&list)
					}
				// // Disable pathway for now.
				// case "tkTBD": {
				// 	setflagprop("values", false)

				// 	list := []string{"tkFVAL", "tkSTR", "tkDLS", "tkBRC_RP", "tkTBD"}
				// 	expect(&list)
				// }
				case "tkSTR":
					{
						setflagprop("values", false)

						list := []string{"tkFVAL", "tkSTR", "tkDLS", "tkBRC_RP", "tkTBD"}
						expect(&list)
					}
				case "tkDLS":
					{
						addscope(kind)
						list := []string{"tkBRC_LP"}
						expect(&list)
					}
				// // [TODO] Pathway needed?
				// case "tkDCMA": {
				// 	list := []string{"tkFVAL", "tkSTR"}
				// 	expect(&list)
				// }
				case "tkBRC_RP":
					{
						popscope(1)
						list := []string{"", "tkDPPE"}
						expect(&list)

						prevtk := prevtoken(&S)
						if prevtk.Kind == "tkBRC_LP" {
							warn(&S, prevtk.Tid, "Empty scope (flag)")
						}
					}
					// // [TODO] Pathway needed?
					// case "tkBRC_RB": {
					// 	popscope(1)
					// 	list := []string{""}
					// 	expect(&list)
					// }
				}

			case "tkDLS":
				switch kind {
				case "tkBRC_LP":
					{
						newvaluegroup("values")
						setflagprop("values", true)

						list := []string{"tkSTR"}
						expect(&list)
					}
				case "tkDLS":
					{
						list := []string{"tkSTR"}
						expect(&list)
					}
				case "tkSTR":
					{
						list := []string{"tkDCMA", "tkBRC_RP"}
						expect(&list)
					}
				case "tkDCMA":
					{
						list := []string{"tkSTR", "tkDLS"}
						expect(&list)
					}
				case "tkBRC_RP":
					{
						popscope(1)

						setflagprop("values", true)

						// Handle: 'program = --flag=$("cmd")'
						// Handle: 'program = default $("cmd")'
						if slices.Contains(tkTYPES_3, prevscope()) {
							if hasscope("tkBRC_LB") {
								popscope(1)
								list := []string{"tkFLG", "tkKYW", "tkBRC_RB"}
								expect(&list)
							} else {
								// Handle: oneliner command-string
								// 'program = --flag|default $("cmd", $"c", "c")'
								// 'program = --flag::f=(1 3)|default $("cmd")|--flag'
								// 'program = --flag::f=(1 3)|default $("cmd")|--flag'
								// 'program = default $("cmd")|--flag::f=(1 3)'
								// 'program = default $("cmd")|--flag::f=(1 3)|default $("cmd")'
								list := []string{"", "tkDPPE", "tkFLG", "tkKYW"}
								expect(&list)
							}

							// Handle: 'program = --flag=(1 2 3 $("c") 4)'
						} else if prevscope() == "tkBRC_LP" {
							list := []string{"tkFVAL", "tkSTR", "tkFOPT", "tkDLS", "tkBRC_RP"}
							expect(&list)

							// Handle: long-form
							// 'program = [
							// 	--flag=(
							// 		- 1
							// 		- $("cmd")
							// 		- true
							// 	)
							// ]'
						} else if prevscope() == "tkOPTS" {
							list := []string{"tkFOPT", "tkBRC_RP"}
							expect(&list)
						}
					}
				}

			case "tkOPTS":
				switch kind {
				case "tkFOPT":
					{
						if prevtoken(&S).Line == line {
							err(&S, S.Tid, "Option same line (nth)", "start", "child")
						}
						list := []string{"tkFVAL", "tkSTR", "tkDLS"}
						expect(&list)
					}
				case "tkDLS":
					{
						addscope("tkDLS") // Build cmd-string.
						list := []string{"tkBRC_LP"}
						expect(&list)
					}
				case "tkFVAL":
					{
						setflagprop("values", false)

						list := []string{"tkFOPT", "tkBRC_RP"}
						expect(&list)
					}
				case "tkSTR":
					{
						setflagprop("values", false)

						list := []string{"tkFOPT", "tkBRC_RP"}
						expect(&list)
					}
				case "tkBRC_RP":
					{
						popscope(2)
						list := []string{"tkFLG", "tkKYW", "tkBRC_RB"}
						expect(&list)
					}
				}

			case "tkBRC_LB":
				switch kind {
				case "tkFLG":
					{
						newflag()

						if hasscope("tkBRC_LB") && token.Line == prevtoken(&S).Line {
							err(&S, S.Tid, "Flag same line (first)", "start", "child")
						}
						addscope(kind)
						list := []string{"tkASG", "tkQMK", "tkDCLN",
							"tkFVAL", "tkDPPE", "tkBRC_RB"}
						expect(&list)
					}
				case "tkKYW":
					{
						newflag()

						if hasscope("tkBRC_LB") && token.Line == prevtoken(&S).Line {
							err(&S, S.Tid, "Keyword same line (first)", "start", "child")
						}
						addscope(kind)
						list := []string{"tkSTR", "tkDLS", "tkBRC_RB"}
						expect(&list)
					}
				case "tkBRC_RB":
					{
						popscope(1)
						list := []string{""}
						expect(&list)

						prevtk := prevtoken(&S)
						if prevtk.Kind == "tkBRC_LB" {
							warn(&S, prevtk.Tid, "Empty scope (command)")
						}
					}
				}

			case "tkKYW":
				switch kind {
				case "tkSTR":
					{
						setflagprop("values", false)

						// Collect exclude values for use upstream.
						if _, exists := S.LexerData.Dtids[S.Tid]; exists {
							prevtk := prevtoken(&S)
							if prevtk.Kind == "tkKYW" &&
								tkstr(&S, prevtk.Tid) == "exclude" {
								exvalues := tkstr(&S, prevtk.Tid)
								exvalues = strings.TrimSpace(exvalues[1 : len(exvalues)-2])
								excl_values := strings.Split(exvalues, ";")

								for _, exvalue := range excl_values {
									S.Excludes = append(S.Excludes, exvalue)
								}
							}
						}

						// [TODO] This pathway re-uses the flag (tkFLG) token
						// pathways. If the keyword syntax were to change
						// this will need to change as it might no loner work.
						popscope(1)
						addscope("tkFLG") // Re-use flag pathways for now.
						list := []string{"", "tkDPPE"}
						expect(&list)
					}
				case "tkDLS":
					{
						addscope(kind) // Build cmd-string.
						list := []string{"tkBRC_LP"}
						expect(&list)
					}
				// // [TODO] Pathway needed?
				// case "tkBRC_RB": {
				// 	popscope(1)
				// 	list := []string{""}
				// 	expect(&list)
				// }
				// // [TODO] Pathway needed?
				// case "tkFLG": {
				// 	list := []string{"tkASG", "tkQMK"
				// 		"tkDCLN", "tkFVAL", "tkDPPE"}
				// 	expect(&list)
				// }
				// // [TODO] Pathway needed?
				// case "tkKYW": {
				// 	addscope(kind)
				// 	list := []string{"tkSTR", "tkDLS"}
				// 	expect(&list)
				// }
				case "tkDPPE":
					{
						// [TODO] Because the flag (tkFLG) token pathways are
						// reused for the keyword (tkKYW) pathways, the scope
						// needs to be removed. This is fine for now but when
						// the keyword token pathway change, the keyword
						// pathways will need to be fleshed out in the future.
						if prevscope() == "tkKYW" {
							popscope(1)
							addscope("tkFLG") // Re-use flag pathways for now.
						}
						list := []string{"tkFLG", "tkKYW"}
						expect(&list)
					}
				}

			case "tkDCMA":
				switch kind {
				case "tkCMD":
					{
						addtoken_group(S.Tid)

						popscope(1)
						list := []string{"", "tkDDOT", "tkASG", "tkDCMA"}
						expect(&list)

						command := tkstr(&S, S.Tid)
						if command != "*" && command != cmdname {
							warn(&S, S.Tid, "Unexpected command:")
						}
					}

				}

			default:
				err(&S, S.LexerData.Tokens[S.Tid].Tid, "Unexpected token:", "end", "")
			}

		}

		i += 1
	}

	// Check for any unused variables and give warning.
	for uservar, value := range USER_VARS {
		if _, exists := USED_VARS[uservar]; !exists {
			for _, tid := range value {
				warn(&S, tid, "Unused variable: "+"'"+uservar+"'")
				S.Warn_lsort.Insert(tokens[tid].Line)
			}
		}
	}

	// Sort warning lines and print issues.
	warnlines := S.Warn_lines.List()
	for _, warnline := range warnlines {
		// Only sort lines where unused variable warning(s) were added.
		if _, exists := S.Warn_lsort[warnline]; exists && len(S.Warnings[warnline]) > 1 {
			warnings := S.Warnings[warnline]
			// [https://stackoverflow.com/a/42872183]
			// [https://yourbasic.org/golang/how-to-sort-in-go/]
			sort.Slice(warnings, func(a, b int) bool {
				return warnings[a].Column < warnings[b].Column
			})
		}
		for _, warning := range S.Warnings[warnline] {
			issue.Issue_warn(warning.Filename, warning.Line,
				warning.Column, warning.Message)
		}
	}
}
