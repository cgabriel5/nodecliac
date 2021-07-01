package main

import (
	"flag"
	"fmt"
	"github.com/cgabriel5/compiler/utils/args"
	"github.com/cgabriel5/compiler/utils/fs"
	"github.com/cgabriel5/compiler/utils/slices"
	"github.com/cgabriel5/compiler/utils/parser"
	"github.com/cgabriel5/compiler/utils/structs"
	"github.com/fatih/color"
	"io/ioutil"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

type TabData = structs.TabData

func main() {

	// [https://stackoverflow.com/a/18973416]
	// [https://yourbasic.org/golang/command-line-arguments/]
	argc := len(os.Args)

	// [https://gobyexample.com/exit]
	if argc == 1 {
		os.Exit(1)
	}

	action := os.Args[1]
	if !slices.Contains([]string{"make", "format"}, action) {
		bold := color.New(color.Bold).SprintFunc()
		fmt.Println("Unknown command " + bold(action) + ".")
		os.Exit(0)
	}

	flagset := flag.NewFlagSet("make", flag.ContinueOnError)
	flagset.Usage = args.Usage // Override default usage function.

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

	fmtinfo := TabData{'\t', 1}

	// Parse/validate indentation.
	if formatting && *indent != "" {
		r, _ := regexp.Compile("^(s|t):\\d+$")
		if !r.MatchString(*indent) {
			fmt.Println("Invalid indentation string.")
			os.Exit(1)
		}
		components := strings.Split(*indent, ":")
		if components[0] == "s" {
			fmtinfo.Ichar = ' '
		} else {
			fmtinfo.Ichar = '\t'
		}
		// [https://stackoverflow.com/a/4279644]
		i, err := strconv.Atoi(components[1])
		if err == nil {
			os.Exit(2)
			fmtinfo.Iamount = i
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
	if !filepath.IsAbs(dirname) {
		res, _ := filepath.Abs(dirname)
		dirname = res
	}

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

	acdef, config, keywords, filedirs,
	contexts, formatted, oPlaceholders, tests := parser.Parser(action, res,
		cmdname, *source, fmtinfo, *trace, *igc, *test)

	testname := cmdname + ".tests.sh"
	savename := cmdname + ".acdef"
	saveconfigname := "." + cmdname + ".config.acdef"

	// Only save files to disk when not testing.
	if !(*test) {
	    if formatting {
	        fs.Write(*source, &formatted, -1)
	    } else {
	        testpath := filepath.Join(dirname, testname)
	        commandpath := filepath.Join(dirname, savename)
	        commandconfigpath := filepath.Join(dirname, saveconfigname)
	        placeholderspaths := filepath.Join(dirname, "placeholders")

			// [https://stackoverflow.com/a/28448702]
	        os.MkdirAll(dirname, os.ModePerm)
	        acdef_ := acdef + keywords + filedirs + contexts
	        fs.Write(commandpath, &acdef_, -1)
	        fs.Write(commandconfigpath, &config, -1)

	        // Save test file if tests were provided.
	        if len(tests) > 0 {
	            fs.Write(testpath, &tests, 0o775)
			}

	        // Create placeholder files if object is populated.
	        // placeholders = placeholders
	        if len(oPlaceholders) > 0 {
	            os.MkdirAll(placeholderspaths, os.ModePerm)

	            for key, value := range oPlaceholders {
	                p := placeholderspaths + string(os.PathSeparator) + key
	                fs.Write(p, &value, -1)
				}
			}
		}
	}

    if *print {
        if !formatting {
			bold := color.New(color.Bold).SprintFunc()
            if len(acdef) > 0 {
                fmt.Println("[" + bold(cmdname + ".acdef") + "]\n")
                fmt.Println(acdef + keywords + filedirs + contexts)
                if len(config) == 0 { fmt.Println("") }
            }
            if len(config) > 0 {
                msg := "\n[" + bold("." + cmdname + ".config.acdef") + "]\n"
                fmt.Println(msg)
                fmt.Println(config)
			}
        } else { fmt.Println(formatted) }
	}

    // Test (--test) purposes.
    if *test {
        if !formatting {
            if len(acdef) > 0 {
                fmt.Println(acdef + keywords + filedirs + contexts)
                if len(config) == 0 { fmt.Println("") }
			}
            if len(config) > 0 {
                if len(acdef) > 0 { fmt.Println("") }
                fmt.Println(config)
			}
        } else { fmt.Println(formatted) }
	}

}
