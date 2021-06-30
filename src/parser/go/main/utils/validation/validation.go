package validation

import (
	"github.com/cgabriel5/compiler/utils/issue"
	"github.com/cgabriel5/compiler/utils/slices"
	"github.com/cgabriel5/compiler/utils/structs"
	"unicode"
)

type StateParse = structs.StateParse
type Warning = structs.Warning

func Vsetting(S *StateParse) {
	token := &(S.LexerData.Tokens[S.Tid])
	start := token.Start
	end := token.End
	line := token.Line
	index := token.Start
	col := index - S.LexerData.LINESTARTS[line]

	settings := []string{"compopt", "filedir", "disable", "placehold", "test"}

	setting := S.Text[start+1 : end+1]

	index_ := slices.Index(len(settings), func(i int) bool {
		return settings[i] == setting
	})

	// Warn if setting is not a supported setting.
	if index_ == -1 {
		message := "Unknown setting: '" + setting + "'"

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
}

func Vvariable(S *StateParse) {
	token := &(S.LexerData.Tokens[S.Tid])
	start := token.Start
	// end := token.End
	line := token.Line
	index := token.Start
	col := index - S.LexerData.LINESTARTS[line]

	// Error when variable starts with a number.
	if unicode.IsDigit(rune(S.Text[start+1])) {
		message := "Unexpected: '" + string(S.Text[start+1]) + "'"
		message += "\n\033[1;36mInfo\033[0m: Variable cannot begin with a number."
		issue.Issue_error(S.Filename, line, col, message)
	}
}

func Vstring(S *StateParse) {
	token := &(S.LexerData.Tokens[S.Tid])
	start := token.Start
	end := token.End
	line := token.Lines[0]
	index := token.Start
	col := index - S.LexerData.LINESTARTS[line]

	// Warn when string is empty.
	// [TODO] Warn if string content is just whitespace?
	if end-start == 1 {
		message := "Empty string"

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

	// Error if string is unclosed.
	if token.Lines[1] == -1 {
		message := "Unclosed string"
		issue.Issue_error(S.Filename, line, col, message)
	}
}

func Vsetting_aval(S *StateParse) {
	token := &(S.LexerData.Tokens[S.Tid])
	start := token.Start
	end := token.End
	line := token.Line
	index := token.Start
	col := index - S.LexerData.LINESTARTS[line]

	values := []string{"true", "false"}

	value := S.Text[start : end+1]

	index_ := slices.Index(len(values), func(i int) bool {
		return values[i] == value
	})

	// Warn if values is not a supported values.
	if index_ == -1 {
		message := "Invalid setting value: '" + value + "'"
		issue.Issue_error(S.Filename, line, col, message)
	}
}
