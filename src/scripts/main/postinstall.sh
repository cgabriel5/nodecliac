#!/bin/bash

# Get path of current script. [https://stackoverflow.com/a/246128]
__filepath="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# If .git folder exists link .githooks with git. For this to work
# git must be >= v2.9.0. [https://stackoverflow.com/a/39338979]
if [[ -d "$PWD/.git" && -n "$(command -v git)" ]]; then
	git config core.hooksPath .githooks
fi

# Reset Bash script shebangs.
"$__filepath/tests/scripts/shebang.sh"

exit 0
