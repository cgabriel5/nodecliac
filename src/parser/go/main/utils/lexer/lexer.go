package lexer

import (
	"github.com/cgabriel5/compiler/utils/bytes"
	"github.com/cgabriel5/compiler/utils/slices"
	"github.com/cgabriel5/compiler/utils/structs"
)

type Token = structs.Token
type State = structs.State

const C_NL = '\n'
const C_DOT = '.'
const C_TAB = '\t'
const C_PIPE = '|'
const C_SPACE = ' '
const C_QMARK = '?'
const C_HYPHEN = '-'
const C_ESCAPE = '\\'
const C_LPAREN = '('
const C_RPAREN = ')'
const C_LCURLY = '{'
const C_RCURLY = '}'
const C_LBRACE = '['
const C_RBRACE = ']'
const C_ATSIGN = '@'
const C_ASTERISK = '*'
const C_DOLLARSIGN = '$'
const C_UNDERSCORE = '_'

var SOT = map[byte]string{ // Start-of-token chars.
	'#':  "tkCMT",
	'@':  "tkSTN",
	'$':  "tkVAR",
	'-':  "tkFLG",
	'?':  "tkQMK",
	'*':  "tkMTL",
	'.':  "tkDDOT",
	'"':  "tkSTR",
	'\'': "tkSTR",
	'=':  "tkASG",
	'|':  "tkDPPE",
	',':  "tkDCMA",
	':':  "tkDCLN",
	';':  "tkTRM",
	'(':  "tkBRC",
	')':  "tkBRC",
	'[':  "tkBRC",
	']':  "tkBRC",
	'{':  "tkBRC",
	'}':  "tkBRC",
	'\n': "tkNL",
}

var BRCTOKENS = map[byte]string{
	C_LPAREN: "tkBRC_LP",
	C_RPAREN: "tkBRC_RP",
	C_LCURLY: "tkBRC_LC",
	C_RCURLY: "tkBRC_RC",
	C_LBRACE: "tkBRC_LB",
	C_RBRACE: "tkBRC_RB",
}

var LINESTARTS = map[int]int{1: -1}

var KEYWORDS = []string{"default", "context", "filedir", "exclude"}

// Invalid command start-of-token chars.
var XCSCOPES = []byte{C_ATSIGN, C_DOT, C_LCURLY, C_RCURLY}

// [https://stackoverflow.com/a/12333839]
// [https://www.geeksforgeeks.org/set-in-cpp-stl/]
var SPACES = []byte{C_SPACE, C_TAB}
var tkCMD_TK_TYPES = []byte{C_HYPHEN, C_ESCAPE}
var tkTBD_TK_TYPES = []byte{
	C_SPACE, C_TAB, C_DOLLARSIGN, C_ATSIGN,
	C_PIPE, C_LCURLY, C_RCURLY, C_LBRACE,
	C_RBRACE, C_LPAREN, C_RPAREN, C_HYPHEN,
	C_QMARK, C_ASTERISK,
}
var tkTBD_TK_TYPES2 = []byte{C_NL, C_SPACE, C_TAB}
var tkEOP_TK_TYPES = []byte{C_SPACE, C_TAB, C_NL}
var tkTYPES_RESET1 = []string{"tkCMD", "tkTBD"}
var tkTYPES_RESET2 = []string{"tkCMD", "tkFLG"}
var tkTYPES_RESET3 = []string{"tkSTN", "tkVAR"}
var tkTYPES_RESET4 = []string{"tkCMT", "tkNL", "tkEOP"}

// Forward loop x amount.
func forward(S *State, amount int) {
	S.I += amount
}

// Rollback loop x amount.
func rollback(S *State, amount int) {
	S.I -= amount
}

// Checks if token is at needed char index.
func charpos(S *State, pos int) bool {
	return S.I-S.Start == pos-1
}

// Checks state object kind matches provided kind.
func kind(S *State, s string) bool {
	return S.Kind == s
}

// Get previous iteration char.
func prevchar(S *State, text string) byte {
	return text[S.I-1]
}

func tk_eop(S *State, char byte, text string) { // Determine in parser.
	S.End = S.I
	if bytes.Contains(tkEOP_TK_TYPES, c) {
		S.End -= 1
	}
	add_token(S, text)
}

// Adds the token to tokens array.
func add_token(S *State, text string) {
	if len(tokens) > 0 && len(ttids) > 0 {
		prevtk := &tokens[ttids[len(ttids)-1]]

		// Keyword reset.
		if kind(S, "tkSTR") && (prevtk.Kind == "tkCMD" ||
			(cmdscope && prevtk.Kind == "tkTBD")) {
			start := prevtk.Start
			end := prevtk.End
			if slices.Contains(KEYWORDS, text[start:end+1]) {
				prevtk.Kind = "tkKYW"
			}

			// Reset: default $("cmd-string")
		} else if kind(S, "tkVAR") && S.End-S.Start == 0 &&
			(prevtk.Kind == "tkCMD" || (cmdscope && prevtk.Kind == "tkTBD")) {
			start := prevtk.Start
			end := prevtk.End
			if text[start:end+1] == "default" {
				prevtk.Kind = "tkKYW"
			}

		} else if valuelist && S.Kind == "tkFLG" && S.Start == S.End {
			S.Kind = "tkFOPT" // Hyphen.

			// When parsing a value list '--flag=()', that is not a
			// string/commang-string should be considered a value.
		} else if valuelist && slices.Contains(tkTYPES_RESET1, S.Kind) {
			S.Kind = "tkFVAL"

			// 'Merge' tkTBD tokens if possible.
		} else if kind(S, "tkTBD") && prevtk.Kind == "tkTBD" &&
			prevtk.Line == S.Line &&
			S.Start-prevtk.End == 1 {
			prevtk.End = S.End
			S.Kind = ""
			return

		} else if kind(S, "tkCMD") || kind(S, "tkTBD") {
			// Reverse loop to get find first command/flag tokens.
			var lastpassed string
			for i := token_count - 1; i > 0; i-- {
				var lkind string
				if val, exists := ttypes[i]; exists {
					lkind = val
				}
				if slices.Contains(tkTYPES_RESET2, lkind) {
					lastpassed = lkind
					break
				}
			}

			// Handle: 'program = --flag::f=123'
			if prevtk.Kind == "tkASG" &&
				prevtk.Line == S.Line &&
				lastpassed == "tkFLG" {
				S.Kind = "tkFVAL"
			}

			if S.Kind != "tkFVAL" && len(ttids) > 1 {
				prevtk2 := tokens[ttids[len(ttids)-2]].Kind

				// Flag alias '::' reset.
				if prevtk.Kind == "tkDCLN" && prevtk2 == "tkDCLN" {
					S.Kind = "tkFLGA"
				}

				// Setting/variable value reset.
				if prevtk.Kind == "tkASG" &&
					slices.Contains(tkTYPES_RESET3, prevtk2) {
					S.Kind = "tkAVAL"
				}
			}
		}
	}

	// Reset when single '$'.
	if kind(S, "tkVAR") && S.End-S.Start == 0 {
		S.Kind = "tkDLS"
	}

	// If a brace token, reset kind to brace type.
	if kind(S, "tkBRC") {
		val, _ := BRCTOKENS[text[S.Start]]
		S.Kind = val
	}

	// Universal command multi-char reset.
	if kind(S, "tkMTL") && (len(tokens) == 0 || tokens[len(tokens)-1].Kind != "tkASG") {
		S.Kind = "tkCMD"
	}

	ttypes[token_count] = S.Kind
	if !slices.Contains(tkTYPES_RESET4, S.Kind) {
		// Track token ids to help with parsing.
		if token_count > 0 && len(ttids) > 0 {
			dtids[token_count] = ttids[len(ttids)-1]
		} else {
			dtids[token_count] = 0
		}
		ttids = append(ttids, token_count)
	}

	copy := Token{
		Kind:  S.Kind,
		Line:  S.Line,
		Start: S.Start,
		End:   S.End,
		Tid:   S.I,
	}

	// Set string line span.
	if S.Lines[0] != -1 {
		copy.Lines[0] = S.Lines[0]
		copy.Lines[1] = S.Lines[1]
		S.Lines[0] = -1
		S.Lines[1] = -1
	}

	if S.Last {
		S.Last = false
	}
	copy.Tid = token_count
	tokens = append(tokens, copy)
	S.Kind = ""

	if S.List {
		S.List = false
	}

	token_count += 1
}

var c byte
var dtids = map[int]int{}
var ttids []int
var tokens []Token
var ttypes = map[int]string{}
var token_count = 0
var cmdscope = false
var valuelist = false // Value list.
var brcparens []int

func Tokenizer(text string) (
	[]Token, map[int]string, []int, map[int]int, map[int]int) {
	l := len(text)

	var S = State{
		I:     0,
		Line:  1,
		Kind:  "",
		Start: -1,
		End:   -1,
		Lines: [2]int{-1, -1},
		Last:  false,
		List:  false,
	}

	for S.I < l {
		c := text[S.I]

		// Add 'last' key on last iteration.
		if S.I == l-1 {
			S.Last = true
		}

		if S.Kind == "" {
			if bytes.Contains(SPACES, c) {
				forward(&S, 1)
				continue
			}

			if c == C_NL {
				S.Line += 1
				LINESTARTS[S.Line] = S.I
			}

			S.Start = S.I
			// [https://stackoverflow.com/a/2050629]
			if val, exists := SOT[c]; exists {
				S.Kind = val
			} else {
				S.Kind = "tkTBD"
			}
			if S.Kind == "tkTBD" {
				if (!cmdscope && bytes.IsAlnum(c)) ||
					(cmdscope && !bytes.Contains(XCSCOPES, c) && bytes.IsAlpha(c)) {
					S.Kind = "tkCMD"
				}
			}
		}

		// Tokenization

		switch S.Kind {
		case "tkSTN":
			if S.I-S.Start > 0 && !bytes.IsAlnum(c) {
				rollback(&S, 1)
				S.End = S.I
				add_token(&S, text)
			}
		case "tkVAR":
			if S.I-S.Start > 0 && !(bytes.IsAlnum(c) || c == C_UNDERSCORE) {
				rollback(&S, 1)
				S.End = S.I
				add_token(&S, text)
			}
		case "tkFLG":
			if S.I-S.Start > 0 && !(bytes.IsAlnum(c) || c == C_HYPHEN) {
				rollback(&S, 1)
				S.End = S.I
				add_token(&S, text)
			}
		case "tkCMD":
			if !(bytes.IsAlnum(c) || bytes.Contains(tkCMD_TK_TYPES, c) ||
				(prevchar(&S, text) == C_ESCAPE)) { // Allow escaped chars.
				rollback(&S, 1)
				S.End = S.I
				add_token(&S, text)
			}
		case "tkCMT":
			if c == C_NL {
				rollback(&S, 1)
				S.End = S.I
				add_token(&S, text)
			}
		case "tkSTR":
			// Store initial line where string starts.
			if S.Lines[0] == -1 {
				S.Lines[0] = S.Line
			}

			// Account for '\n's in string to track where string ends
			if c == C_NL {
				S.Line += 1
				LINESTARTS[S.Line] = S.I
			}

			if !charpos(&S, 1) && c == text[S.Start] &&
				prevchar(&S, text) != C_ESCAPE {
				S.End = S.I
				S.Lines[1] = S.Line
				add_token(&S, text)
			}
		case "tkTBD":
			S.End = S.I
			if c == C_NL || bytes.Contains(tkTBD_TK_TYPES, c) &&
				(prevchar(&S, text) != C_ESCAPE) {
				if !bytes.Contains(tkTBD_TK_TYPES2, c) {
					rollback(&S, 1)
					S.End = S.I
				} else {
					// Let '\n' pass through to increment line count.
					if c == C_NL {
						rollback(&S, 1)
					}
					S.End -= 1
				}
				add_token(&S, text)
			}
		case "tkBRC":
			if c == C_LPAREN {
				if tokens[ttids[len(ttids)-1]].Kind != "tkDLS" {
					valuelist = true
					brcparens = append(brcparens, 0) // Value list.
					S.List = true
				} else {
					brcparens = append(brcparens, 1)
				} // Command-string.
			} else if c == C_RPAREN {
				// [https://code-maven.com/slides/golang/slice-remove-from-the-end]
				// brcparens = brcparens[:len(brcparens)-1]
				last_brcparens := slices.Pop(&brcparens)
				if last_brcparens == 0 {
					valuelist = false
					S.List = true
				}
			} else if c == C_LBRACE {
				cmdscope = true
			} else if c == C_RBRACE {
				cmdscope = false
			}
			S.End = S.I
			add_token(&S, text)

		default: // tkDEF
			S.End = S.I
			add_token(&S, text)
		}

		// Run on last iteration.
		if S.Last {
			tk_eop(&S, c, text)
		}

		forward(&S, 1)
	}

	// To avoid post parsing checks, add a special end-of-parsing token.
	S.Kind = "tkEOP"
	S.Start = -1
	S.End = -1
	add_token(&S, text)

	return tokens, ttypes, ttids, dtids, LINESTARTS
}
