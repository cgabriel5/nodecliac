package lexer

import (
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

var BRCTOKENS = map[string]string{
	"C_LPAREN": "tkBRC_LP",
	"C_RPAREN": "tkBRC_RP",
	"C_LCURLY": "tkBRC_LC",
	"C_RCURLY": "tkBRC_RC",
	"C_LBRACE": "tkBRC_LB",
	"C_RBRACE": "tkBRC_RB",
}

var LINESTARTS = map[int]int{1: -1}

var KEYWORDS = [4]string{"default", "context", "filedir", "exclude"}
// Invalid command start-of-token chars.
var XCSCOPES = [4]byte{C_ATSIGN, C_DOT, C_LCURLY, C_RCURLY}

var c byte
var dtids = map[int]int{}
var ttids []int
var tokens []Token
var ttypes = map[int]string{}
var token_count = 0
var cmdscope = false
var valuelist = false // Value list.
var brcparens []int

func Tokenizer(text string) {
	l := len(text)

	var S = State{
		I: 0,
		Line: 1,
		Kind: "",
		Start: -1,
		End: -1,
		Lines: [2]int{-1, -1},
		Last: false,
		List: false,
	}

	for S.I < l {
		c := text[S.I]

		// Add 'last' key on last iteration.
		if (S.I == l - 1) { S.Last = true }

		S.I += 1
	}
}
