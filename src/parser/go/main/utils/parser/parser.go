package parser

import (
	"github.com/cgabriel5/compiler/utils/structs"
	"github.com/cgabriel5/compiler/utils/lexer"
)

type TabData = structs.TabData

func Parser(action, text, cmdname, source string, fmtinfo TabData, trace, igc, test bool) {
	lexer.Tokenizer(text)
}
