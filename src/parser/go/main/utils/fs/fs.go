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
type FileInfo structs.FileInfo

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
