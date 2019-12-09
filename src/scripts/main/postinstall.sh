#!/bin/bash

chipdir() {
	local dir="$1" # The provided directory path.
	# Remove last directory from path.
	for ((x=0; x<"$2"; x++)); do dir="${dir%/*}"; done
	echo "$dir" # Return modified path.
}

# Get path of current script. [https://stackoverflow.com/a/246128]
__filepath="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# If .git folder exists link .githooks with git. For this to work
# git must be >= v2.9.0. [https://stackoverflow.com/a/39338979]
if [[ -d "$PWD/.git" && -n "$(command -v git)" ]]; then
	git config core.hooksPath .githooks
fi

# Reset Bash script shebangs.
"$(chipdir "$__filepath" 3)""/tests/scripts/shebang.sh"

exit 0
