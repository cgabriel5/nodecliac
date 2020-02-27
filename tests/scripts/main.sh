#!/bin/bash

# Runs project test scripts.

# Available flags:
# --force    [-f]: Force tests: true|false
# --print    [-p]: Log output: true|false
# --override [-o]: Override used complete script with: nim|pl

# ---------------------------------------------------------------- CLI-ARGUMENTS

PRINT="true"
FORCE="false" # Forces tests to run regardless of conditions.
OVERRIDE=""

OPTIND=1 # Reset variable: [https://unix.stackexchange.com/a/233737]
# [https://stackoverflow.com/a/18003735], [https://stackoverflow.com/a/18118360]
# [https://sookocheff.com/post/bash/parsing-bash-script-arguments-with-shopts/]
while getopts 'p:f:o:' flag; do
	case "$flag" in
		p)
			case "$OPTARG" in
				true) PRINT="$OPTARG" ;;
				false) PRINT="" ;;
				*) PRINT="true" ;;
			esac ;;
		f)
			case "$OPTARG" in
				true) FORCE="$OPTARG" ;;
				*) FORCE="" ;;
			esac ;;
		o)
			case "$OPTARG" in
				nim | pl) OVERRIDE="$OPTARG" ;;
				*) OVERRIDE="" ;;
			esac
	esac
done
shift $((OPTIND - 1))

# Get path of current script. [https://stackoverflow.com/a/246128]
__filepath="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# ---------------------------------------------------------------------- IMPORTS

. "$__filepath/common.sh"

# ------------------------------------------------------------------------- VARS

ROOTDIR=$(chipdir "$__filepath" 2)
TESTDIR="$ROOTDIR/tests/scripts"

args=() # [https://stackoverflow.com/a/1951554]
if [[ -n "$PRINT" ]]; then args+=("-p"); args+=("$PRINT"); fi
if [[ -n "$FORCE" ]]; then args+=("-f"); args+=("$FORCE"); fi
if [[ -n "$OVERRIDE" ]]; then args+=("-o"); args+=("$OVERRIDE"); fi

# ------------------------------------------------------------------------ TESTS

# Run tests with arguments: [https://stackoverflow.com/a/16989110]
# [https://stackoverflow.com/a/42985721]
# [https://stackoverflow.com/a/42985721]
# [https://unix.stackexchange.com/a/465024]
# Or set arguments: [https://unix.stackexchange.com/a/284545]
"$TESTDIR/nodecliac.sh" "${args[@]}" && \
"$TESTDIR/parser.sh" "${args[@]}" && \
"$TESTDIR/formatter.sh" "${args[@]}" && \
"$TESTDIR/executables.sh" "${args[@]}"
