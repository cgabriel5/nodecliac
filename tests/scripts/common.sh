#!/bin/bash

# Common functions and variables used across the test scripts.

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

# ---------------------------------------------------------------------VARIABLES

# [https://www.utf8-chartable.de/unicode-utf8-table.pl?start=9984&number=128&names=-&utf8=string-literal]
# [https://misc.flogisoft.com/bash/tip_colors_and_formatting]
CHECK_MARK="\033[0;32m\xE2\x9C\x94\033[0m"
X_MARK="\033[0;31m\xe2\x9c\x98\033[0m"

# Get list of staged files. [https://stackoverflow.com/a/33610683]
STAGED_FILES=$(git diff --name-only --cached)
