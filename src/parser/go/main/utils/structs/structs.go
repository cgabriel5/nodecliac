package structs

type Token struct {
	Kind, Str_rep string
	Line, Start, End, Tid int
	Lines [2]int // = {-1, -1};
}

type State struct {
	I, Line, Start, End int
	Kind string
	Last, List bool
	Lines [2]int
}

// -----------------------------------------------------------------------------

// [https://www.callicoder.com/golang-basic-types-operators-type-conversion/]
type TabData struct {
	Ichar   byte
	Iamount int
}

type FileInfo struct {
	Name, Dirname, Ext, Path string
}
