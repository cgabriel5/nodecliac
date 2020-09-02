#!/bin/bash

# Common functions and variables used across the test scripts.

# -------------------------------------------------------------------- FUNCTIONS

# [https://stackoverflow.com/questions/10986794/remove-part-of-path-on-unix]
chipdir() {
	local dir="$1"
	# Remove last directory from path.
	for ((x=0; x<"$2"; x++)); do dir="${dir%/*}"; done
	echo "$dir"

	# Note: The built-in function `dirname` can also be used
	# to remove the last directory from a path.
	# [https://unix.stackexchange.com/a/28773]
	# Example: $(dirname "$dir")

	# Param expan. with a loop can also be used.
	# [https://stackoverflow.com/a/4170409]
}

# If provided value is not empty return 1, else return "".
# Note: o is not returned because it is considered true by Bash so 
# "" is returned instead: [https://stackoverflow.com/a/3924230]
# [https://stackoverflow.com/a/3601734]
isset() {
	echo $([[ -n "$1" ]] && echo 1 || echo "")
}
# If provided value is empty return 1, else return "".
# Note: o is not returned because it is considered true by Bash so 
# "" is returned instead: [https://stackoverflow.com/a/3924230]
notset() {
	echo $([[ -z "$1" ]] && echo 1 || echo "")
}

# ------------------------------------------------------------------------- VARS

# ANSI colors: [https://stackoverflow.com/a/5947802]
# [https://misc.flogisoft.com/bash/tip_colors_and_formatting]
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
# Bold colors.
BOLD="\033[1m"
BRED="\033[1;31m"
BGREEN="\033[1;32m"
BBLUE="\033[1;34m"
BPURPLE="\033[1;35m"
BTURQ="\033[1;36m"
# Special
DEFAULT="\033[0;39m"
NC="\033[0m"
DIM="\033[2m"

# [https://www.utf8-chartable.de/unicode-utf8-table.pl?start=9984&number=128&names=-&utf8=string-literal]
# [https://misc.flogisoft.com/bash/tip_colors_and_formatting]
CHECK_MARK="${GREEN}\xE2\x9C\x94${NC}"
X_MARK="${RED}\xe2\x9c\x98${NC}"
