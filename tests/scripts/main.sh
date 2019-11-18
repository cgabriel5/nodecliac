#!/bin/bash

# Runs project test scripts.

# -----------------------------------------------------------------CLI-ARGUMENTS

LOG_SILENT=0

while getopts 's' flag; do
	case "$flag" in
		s) LOG_SILENT=1 ;;
	esac
done

# ---------------------------------------------------------------------FUNCTIONS

# [https://stackoverflow.com/questions/10986794/remove-part-of-path-on-unix]
chipdir() {
	local dir="$1" # The provided directory path.
	# Remove last directory from path.
	for ((x=0; x<"$2"; x++)); do dir="${dir%/*}"; done
	echo "$dir" # Return modified path.

	# Note: The built-in function `dirname` can also be used
	# to remove the last directory from a path.
	# [https://unix.stackexchange.com/a/28773]
	# Example: $(dirname "$dir")
	
	# Or parameter expansion with a loop can be used to remove
	# the last directory.
	# [https://stackoverflow.com/a/4170409]
}

# Get path of current script. [https://stackoverflow.com/a/246128]
fpath() {
	echo "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
}

# ---------------------------------------------------------------------FUNCTIONS

ROOTDIR=$(chipdir "$(fpath)" 2) # Get the project's root directory.
TESTDIR="$ROOTDIR/tests/scripts" # The tests script's path.

# --------------------------------------------------------------------------VARS

# Check whether to pass silent flag.
silent=""
if [[ "$LOG_SILENT" == 1 ]]; then silent="-s"; fi

# Run tests.
"$TESTDIR/nodecliac.sh" "$silent" && echo "" && \
"$TESTDIR/parser.sh" "$silent" && echo "" && \
"$TESTDIR/formatter.sh" "$silent" && echo "" && \
"$TESTDIR/executables.sh" "$silent"
