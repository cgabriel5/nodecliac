package main

import (
	"flag"
	"fmt"
	"github.com/fatih/color"
	"os"
	"regexp"
	"strconv"
	"strings"
)

// [https://stackoverflow.com/a/35966287]
func Use(vals ...interface{}) {
	for _, val := range vals {
		_ = val
	}
}

func main() {

	// [https://stackoverflow.com/a/18973416]
	argc := len(os.Args)

	// [https://gobyexample.com/exit]
	if argc == 1 {
		os.Exit(1)
	}

	// [https://www.rapid7.com/blog/post/2016/08/04/build-a-simple-cli-tool-with-golang/]
	// [https://gobyexample.com/command-line-flags]
	igc := flag.Bool("igc", false, "")
	test := flag.Bool("test", false, "")
	print := flag.Bool("print", false, "")
	trace := flag.Bool("trace", false, "")
	action := flag.String("action", "", "")
	indent := flag.String("indent", "t:1", "")
	source := flag.String("source", "", "")
	flag.Parse()

	formatting := *action == "format"

	// [https://www.callicoder.com/golang-basic-types-operators-type-conversion/]
	type tabdata struct {
		ichar   byte
		iamount int
	}
	fmtinfo := tabdata{'\t', 1}

	// Parse/validate indentation.
	if formatting && *indent != "" {
		r, _ := regexp.Compile("^(s|t):\\d+$")
		if !r.MatchString(*indent) {
			fmt.Println("Invalid indentation string.")
			os.Exit(1)
		}
		components := strings.Split(*indent, ":")
		if components[0] == "s" {
			fmtinfo.ichar = ' '
		} else {
			fmtinfo.ichar = '\t'
		}
		// [https://stackoverflow.com/a/4279644]
		i, err := strconv.Atoi(components[1])
		if err == nil {
			os.Exit(2)
			fmtinfo.iamount = i
		}
	}

	// Source must be provided.
	if *source == "" {
		bold := color.New(color.Bold).SprintFunc()
		fmt.Println("Please provide a", bold("--source"), "path.")
		os.Exit(0)
	}

	Use(igc, test, print, trace, action, indent, source, formatting, fmtinfo)

	fmt.Println("SUCCESS", *igc == false, *igc, formatting)

}
