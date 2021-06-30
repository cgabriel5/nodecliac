package issue

import (
	"fmt"
	"os"
	"strconv"
)

func Issue_hint(filename string, line int, col int, message string) {
	itype := "\033[32;1mHint:\033[0m"
	fileinfo := "\033[1m" + filename + "(" + strconv.Itoa(line) + ", " + strconv.Itoa(col) + ")\033[0m"

	fmt.Println(fileinfo + " " + itype + " " + message)
}

func Issue_warn(filename string, line int, col int, message string) {
	itype := "\033[33;1mWarning:\033[0m"
	fileinfo := "\033[1m" + filename + "(" + strconv.Itoa(line) + ", " + strconv.Itoa(col) + ")\033[0m"

	fmt.Println(fileinfo + " " + itype + " " + message)
}

func Issue_error(filename string, line int, col int, message string) {
	itype := "\033[31;1mError:\033[0m"
	fileinfo := "\033[1m" + filename + "(" + strconv.Itoa(line) + ", " + strconv.Itoa(col) + ")\033[0m"

	fmt.Println(fileinfo + " " + itype + " " + message)
	os.Exit(1)
}
