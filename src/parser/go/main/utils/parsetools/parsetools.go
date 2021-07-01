package parsetools

import (
	"github.com/cgabriel5/compiler/utils/structs"
)

type StateParse = structs.StateParse

func Tkstr(S *StateParse, tid int) string {
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
