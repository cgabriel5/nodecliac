#!/bin/bash

# Script checks if `nodecliac make` returns same output. If so
# the parser is working properly.

# ---------------------------------------------------------------- CLI-ARGUMENTS

PRINT=""
FORCE=""

OPTIND=1 # Reset variable: [https://unix.stackexchange.com/a/233737]
while getopts 'p:f:o:' flag; do # [https://stackoverflow.com/a/18003735]
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
			esac
	esac
done
shift $((OPTIND - 1))

# ------------------------------------------------------------------------- VARS

ACTION="parse"
OUTPUT_DIR="parsers"
HEADER="Parser"
EXTENSION="acdef"

# Get path of current script. [https://stackoverflow.com/a/246128]
__filepath="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

args=() # Contain arguments in an array.
if [[ -n "$PRINT" ]]; then args+=("-p"); args+=("$PRINT"); fi
if [[ -n "$FORCE" ]]; then args+=("-f"); args+=("$FORCE"); fi

# ---------------------------------------------------------------------- IMPORTS

. "$__filepath/common.sh"

# ---------------------------------------------------------------- RUN-TEST-FILE

. "$__filepath/clitools.sh" "${args[@]}"
