package defvars

import (
	"os"
	"runtime"
)

// Builtin variables.
func Builtins(cmdname string) map[string]string {
	// [https://stackoverflow.com/a/13004756]
	hdir, _ := os.UserHomeDir()

	return map[string]string{
		"HOME": hdir,
		// [https://golangcode.com/detect-if-code-is-running-on-windows-at-runtime/]
		// [https://stackoverflow.com/a/19847868]
		// [https://stackoverflow.com/a/30068222]
		// [https://stackoverflow.com/a/53197771]
		"OS": runtime.GOOS,
		"COMMAND": cmdname,
		"PATH": "~/.nodecliac/registry/" + cmdname,
	}
}
