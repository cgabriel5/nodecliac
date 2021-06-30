package structs

type Token struct {
	Kind, Str_rep string
	Line, Start, End, Tid int
	Lines [2]int // = {-1, -1}
}

type LexerResponse struct {
	Tokens []Token
	Ttypes map[int]string
	Ttids []int
	Dtids map[int]int
	LINESTARTS map[int]int // {1, -1}
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

type Args struct {
	Action, Source string
	Fmt TabData
	Trace, Igc, Test bool
}

type Warning struct {
	Filename, Message string
	Line, Column int
}

type StateParse struct {
	Tid int // = -1
	Filename string // = source
	Text string // = text
	LexerData LexerResponse
	Args Args
	Ubids []int
	Excludes []string
	Warnings map[int][]Warning
	Warn_lines []int // set?
	Warn_lsort []int // set?
}

type Flag struct {
	Tid int // -1
	Alias int // -1
	Boolean int // -1
	Assignment int // -1
	Multi int // -1
	Union_ int // -1
	Values [][]int
}

// -----------------------------------------------------------------------------

type FileInfo struct {
	Name, Dirname, Ext, Path string
}
