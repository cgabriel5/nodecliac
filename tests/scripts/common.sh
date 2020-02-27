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

# [https://www.utf8-chartable.de/unicode-utf8-table.pl?start=9984&number=128&names=-&utf8=string-literal]
# [https://misc.flogisoft.com/bash/tip_colors_and_formatting]
CHECK_MARK="\033[0;32m\xE2\x9C\x94\033[0m"
X_MARK="\033[0;31m\xe2\x9c\x98\033[0m"

# Get list of staged files. [https://stackoverflow.com/a/33610683]
STAGED_FILES=$(git diff --name-only --cached)
