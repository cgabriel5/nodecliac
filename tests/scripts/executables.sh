#!/bin/bash

# If binary files (ac.macosx or ac.linux) are staged this script
# checks whether the file(s) are executable. If not the script fails.

# ---------------------------------------------------------------- CLI-ARGUMENTS

PRINT=""

OPTIND=1 # Reset variable: [https://unix.stackexchange.com/a/233737]
while getopts 'p:f:o:' flag; do # [https://stackoverflow.com/a/18003735]
	case "$flag" in
		p)
			case "$OPTARG" in
				true) PRINT="$OPTARG" ;;
				false) PRINT="" ;;
				*) PRINT="true" ;;
			esac
	esac
done
shift $((OPTIND - 1))

# Get path of current script. [https://stackoverflow.com/a/246128]
__filepath="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# ---------------------------------------------------------------------- IMPORTS

. "$__filepath/common.sh"

# ------------------------------------------------------------------------- VARS

# Get list of staged files. [https://stackoverflow.com/a/33610683]
STAGED_FILES=$(git diff --name-only --cached)

# If no files are staged then exit.
if [[ -z "$STAGED_FILES" ]]; then
	if [[ $(isset "$PRINT") ]]; then
		echo -e "\033[1m[Binary Executables]\033[0m"
	fi

	if [[ $(isset "$PRINT") ]]; then
		echo -e " $CHECK_MARK [skipped] No staged binaries."
		echo ""
	fi

	exit 0
fi

# Read staged files list into an array.
readarray -t list <<< "$STAGED_FILES" # [https://stackoverflow.com/a/19772067]

ROOTDIR=$(chipdir "$__filepath" 2) # Get the project's root directory.

# Declare empty array to contain unexecutable binaries.
declare -a binaries # [https://stackoverflow.com/a/41108078]

# Loop over files list.
for file in "${list[@]}"; do # [https://www.cyberciti.biz/faq/bash-for-loop-array/]
	# If file is macOS/Linux binary check that's executable.
	# [https://unix.stackexchange.com/a/340485]
	if [[ "$file" =~ ac\.(macosx|linux)$ ]]; then
		filepath="$ROOTDIR/$file" # The file's complete path.

		# If file is not executable exit with error.
		# [https://stackoverflow.com/a/49707794]
		if [[ ! -e "$filepath" || ! -x $(realpath "$filepath") ]]; then
			binaries+=($(basename "$file")) # [https://stackoverflow.com/a/1951523]
		fi
	fi
done

# If array is populated there are errors.
if [[ ${#binaries[@]} -ne 0 ]]; then # [https://serverfault.com/a/477506]
	if [[ $(isset "$PRINT") ]]; then
		echo -e "\033[1m[Binary Executables]\033[0m"
	fi

	if [[ $(isset "$PRINT") ]]; then
		for binfile in "${binaries[@]}"; do		
			echo -e " $X_MARK Make executable: \033[1;36m$binfile\033[0m"
		done
	fi
	
	echo ""
	exit 1 # Give error to stop git.
fi

# If this block gets is there were no staged binaries so give message.
if [[ $(isset "$PRINT") ]]; then
	echo -e "\033[1m[Binary Executables]\033[0m"
fi

if [[ $(isset "$PRINT") ]]; then
	echo -e " $CHECK_MARK No staged binaries."
	echo ""
fi

exit 0
