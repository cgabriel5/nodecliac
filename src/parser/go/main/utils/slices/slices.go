package slices

// [https://freshman.tech/snippets/go/check-if-slice-contains-element/]
// https://play.golang.org/p/Qg_uv_inCek
// [https://stackoverflow.com/a/10485970]
// contains checks if a string is present in a slice
func Contains(s []string, str string) bool {
	for _, v := range s {
		if v == str {
			return true
		}
	}
	return false
}
