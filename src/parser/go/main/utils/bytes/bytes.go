package bytes

import (
	"unicode"
)

// [https://freshman.tech/snippets/go/check-if-slice-contains-element/]
// https://play.golang.org/p/Qg_uv_inCek
// [https://stackoverflow.com/a/10485970]
// contains checks if a string is present in a slice
func Contains(s []byte, char byte) bool {
	for _, v := range s {
		if v == char {
			return true
		}
	}
	return false
}

// [https://stackoverflow.com/a/38554480]
func IsAlpha(char byte) bool {
	return unicode.IsLetter(rune(char))
}

// [https://stackoverflow.com/a/25540992]
func IsAlnum(char byte) bool {
	r := rune(char)
	return unicode.IsLetter(r) || unicode.IsDigit(r)
}
