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

// [https://stackoverflow.com/a/52550607]
func Pop(s *[]int) int {
	l := len(*s)
	last := (*s)[l-1]
	*s = append((*s)[:l-1])
	return last
}

// [https://stackoverflow.com/a/18203895]
// [https://gobyexample.com/collection-functions]
func Index(limit int, predicate func(i int) bool) int {
    for i := 0; i < limit; i++ {
        if predicate(i) {
            return i
        }
    }
    return -1
}
