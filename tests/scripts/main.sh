#!/bin/bash

# Runs project test scripts.

# -----------------------------------------------------------------CLI-ARGUMENTS

LOG_SILENT=0

while getopts 's' flag; do
	case "$flag" in
		s) LOG_SILENT=1 ;;
	esac
done

# Get path of current script. [https://stackoverflow.com/a/246128]
__filepath="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# -----------------------------------------------------------------------IMPORTS

. "$__filepath/common.sh" # Import functions/variables.

# ---------------------------------------------------------------------FUNCTIONS

ROOTDIR=$(chipdir "$__filepath" 2) # Get the project's root directory.
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
