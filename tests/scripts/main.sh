#!/bin/bash

# Runs project test scripts.

# -----------------------------------------------------------------CLI-ARGUMENTS

LOG_SILENT=0

while getopts 's' flag; do
	case "$flag" in
		s) LOG_SILENT=1 ;;
	esac
done

# ----------------------------------------------------------------RUN-TEST-SUITE

TESTDIR="$PWD/tests/scripts" # The tests script's path.

# Check whether to pass silent flag.
silent=""
if [[ "$LOG_SILENT" == 1 ]]; then silent="-s"; fi

# Run tests.
"$TESTDIR/nodecliac.sh" "$silent" && echo "" && \
"$TESTDIR/parser.sh" "$silent" && echo "" && \
"$TESTDIR/formatter.sh" "$silent" && echo "" && \
"$TESTDIR/executables.sh" "$silent" && echo ""
