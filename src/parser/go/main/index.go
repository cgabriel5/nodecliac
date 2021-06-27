package main

import (
	"flag"
	"fmt"
	"github.com/cgabriel5/compiler/utils/fs"
	"github.com/fatih/color"
	"io/ioutil"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

// [https://stackoverflow.com/a/46381939]
func Usage() {

}

// [https://stackoverflow.com/a/62951339]
func X(x ...interface{}) {}

// [https://freshman.tech/snippets/go/check-if-slice-contains-element/]
// https://play.golang.org/p/Qg_uv_inCek
// [https://stackoverflow.com/a/10485970]
// contains checks if a string is present in a slice
func contains(s []string, str string) bool {
	for _, v := range s {
		if v == str {
			return true
		}
	}
	return false
}

func main() {

	// [https://stackoverflow.com/a/18973416]
	// [https://yourbasic.org/golang/command-line-arguments/]
	argc := len(os.Args)

	// [https://gobyexample.com/exit]
	if argc == 1 {
		os.Exit(1)
	}

	action := os.Args[1]
	if !contains([]string{"make", "format"}, action) {
		bold := color.New(color.Bold).SprintFunc()
		fmt.Println("Unknown command " + bold(action) + ".")
		os.Exit(0)
	}

	flagset := flag.NewFlagSet("make", flag.ContinueOnError)
	flagset.Usage = Usage // Override default usage function.

	// [https://www.rapid7.com/blog/post/2016/08/04/build-a-simple-cli-tool-with-golang/]
	// [https://gobyexample.com/command-line-flags]
	// [https://gobyexample.com/command-line-subcommands]
	// [https://www.digitalocean.com/community/tutorials/how-to-use-the-flag-package-in-go]
	igc := flagset.Bool("igc", false, "")
	test := flagset.Bool("test", false, "")
	print := flagset.Bool("print", false, "")
	trace := flagset.Bool("trace", false, "")
	indent := flagset.String("indent", "t:1", "")
	source := flagset.String("source", "", "")
	formatting := action == "format"

	// [https://stackoverflow.com/a/44461997]
	flag.CommandLine.SetOutput(ioutil.Discard)
	flagset.SetOutput(ioutil.Discard)

	flagset.Parse(os.Args[2:])
	// if err := flagset.Parse(os.Args[2:]); err != nil {}
	// flagset.Args() // Positional arguments.

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

	// Breakdown path.
	fi := fs.Info(*source)
	extension := fi.Ext
	dirname := fi.Dirname

	// [https://gobyexample.com/regular-expressions]
	r, _ := regexp.Compile("\\." + extension + "$")
	cmdname := r.ReplaceAllString(fi.Name, "") // [TODO] `replace`

	// Make path absolute.
	if !filepath.IsAbs(*source) {
		res, _ := filepath.Abs(*source)
		source = &res
	}

	// [https://freshman.tech/snippets/go/check-if-file-is-dir/]
	// [https://golangbyexample.com/check-if-file-is-a-directory-go/]
	// [https://stackoverflow.com/a/40624033]
	// [https://stackoverflow.com/a/51077254]
	fileInfo, err := os.Stat(*source)
	if err != nil {
		bold := color.New(color.Bold).SprintFunc()
		fmt.Println("Path " + bold(*source) + " doesn't exist.")
		os.Exit(0)
	}
	if fileInfo.IsDir() {
		fmt.Println("Directory provided but .acmap file path needed.")
		os.Exit(0)
	}

	// [https://gobyexample.com/reading-files]
	data, err := ioutil.ReadFile(*source)
	// if err != nil { panic(err) }
	res := string(data)

	X(res, dirname, cmdname, igc, test, print, trace)

}
