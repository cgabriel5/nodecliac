package fs

import (
	"github.com/cgabriel5/compiler/utils/structs"
	"os"
	"path"
	"path/filepath"
	"strings"
)

// [https://stackoverflow.com/a/53474756]
// [https://stackoverflow.com/a/39491635]
// [https://stackoverflow.com/a/63636447]
// import t "github.com/cgabriel5/parser/utils/structs"
type FileInfo = structs.FileInfo

func Info(p string) FileInfo {
	var fi = FileInfo{}

	// [https://www.dotnetperls.com/path-go]
	head, tail := path.Split(p)
	ext := filepath.Ext(tail) // [https://stackoverflow.com/a/13027975]

	fi.Dirname = head
	if fi.Dirname == "" {
		fi.Dirname = "."
	}
	fi.Path = p

	if ext != "" {
		fi.Name = tail
		fi.Ext = ext[1:len(ext)]
	} else {
		// [https://stackoverflow.com/a/48683627]
		path_parts := strings.Split(p, string(os.PathSeparator))
		name := path_parts[len(path_parts)-1]
		name_parts := strings.Split(name, ".")
		if len(name_parts) > 0 {
			fi.Name = name
			fi.Ext = name_parts[len(name_parts)-1]
		}
	}

	return fi
}

func Write(p string, data *string, mode int) {
	// [TODO] Improve error handling.

	// [https://zetcode.com/golang/writefile/]
	// [https://gobyexample.com/writing-files]
	f, err := os.Create(p)
	if err != nil { /*log.Fatal(err)*/ }
	defer f.Close()
	_, err2 := f.WriteString(*data)
	if err2 != nil { /*log.Fatal(err2)*/ }

	// [https://golangbyexample.com/change-file-permissions-golang/]
	if mode != -1 {
		// [https://stackoverflow.com/q/48123541]
		// [https://stackoverflow.com/a/28969523]
		// [https://www.socketloop.com/tutorials/golang-change-file-read-or-write-permission-example]
		// [https://golang.hotexamples.com/examples/os/FileMode/-/golang-filemode-class-examples.html]
		err = os.Chmod(p, os.FileMode(mode))
		if err != nil { /*log.Fatal(err)*/ }
	}
}
