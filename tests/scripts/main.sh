#!/bin/bash

# Runs project test scripts.

# Available flags:
# force      [-f]: Force tests: true|false
# print      [-p]: Log output: true|false
# override   [-o]: Override used complete script with: nim|pl
# names      [-n]: Names of tests to run: c|x|a|p|f: example: acx
# tests      [-t]: Test file path to pass to nodecliac.sh (ac tests).
# test debug [-d]: Print verbose debug information for tests (ac tests).

# ---------------------------------------------------------------- CLI-ARGUMENTS

PRINT="true"
FORCE="false" # Forces tests to run regardless of conditions.
OVERRIDE=""
TESTS=""
TNAMES=""
TDEBUG=""

OPTIND=1 # Reset variable: [https://unix.stackexchange.com/a/233737]
# [https://stackoverflow.com/a/18003735], [https://stackoverflow.com/a/18118360]
# [https://sookocheff.com/post/bash/parsing-bash-script-arguments-with-shopts/]
while getopts ':n:t:d:p:f:o:' flag; do
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
			esac ;;
		t) [[ -n "$OPTARG" ]] && TESTS="$OPTARG" ;;
		d) [[ -n "$OPTARG" ]] && TDEBUG="$OPTARG" ;;
		n) [[ -n "$OPTARG" ]] && TNAMES="$OPTARG" ;;
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

args=(); targs=() # [https://stackoverflow.com/a/1951554]
[[ -n "$PRINT" ]] && args+=("-p"); args+=("$PRINT"); targs+=("-p"); targs+=("$PRINT");
[[ -n "$FORCE" ]] && args+=("-f"); args+=("$FORCE"); targs+=("-f"); targs+=("$FORCE");
[[ -n "$TDEBUG" ]] && args+=("-d"); args+=("$TDEBUG"); targs+=("-d"); targs+=("$TDEBUG");
[[ -n "$OVERRIDE" ]] && args+=("-o"); args+=("$OVERRIDE"); targs+=("-o"); targs+=("$OVERRIDE");
[[ -n "$TESTS" ]] && targs+=("-t"); targs+=("$TESTS")

# ------------------------------------------------------------------------ TESTS

# Run tests with arguments: [https://stackoverflow.com/a/16989110]
# [https://stackoverflow.com/a/42985721]
# [https://stackoverflow.com/a/42985721]
# [https://unix.stackexchange.com/a/465024]
# Or set arguments: [https://unix.stackexchange.com/a/284545]
# Run all tests when non are specified.
if [[ -z "$TNAMES" ]]; then
	"$TESTDIR/checksum.sh" "${args[@]}"
	"$TESTDIR/executables.sh" "${args[@]}"
	"$TESTDIR/nodecliac.sh" "${targs[@]}"
	"$TESTDIR/parser.sh" "${args[@]}"
	"$TESTDIR/formatter.sh" "${args[@]}"
else
	[[ "$TNAMES" == *c* ]] && "$TESTDIR/checksum.sh" "${args[@]}"
	[[ "$TNAMES" == *x* ]] && "$TESTDIR/executables.sh" "${args[@]}"
	[[ "$TNAMES" == *a* ]] && "$TESTDIR/nodecliac.sh" "${targs[@]}"
	[[ "$TNAMES" == *p* ]] && "$TESTDIR/parser.sh" "${args[@]}"
	[[ "$TNAMES" == *f* ]] && "$TESTDIR/formatter.sh" "${args[@]}"
fi
