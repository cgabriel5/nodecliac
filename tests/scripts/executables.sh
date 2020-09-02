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

ROOTDIR=$(chipdir "$__filepath" 2) # Get the project's root directory.

# Print script executable permission.
if [[ $(isset "$PRINT") ]]; then
	c=0
	echo -e "${BOLD}[Script Executables]${NC}"
	for f in  "$ROOTDIR"/*.sh "$ROOTDIR"/src/scripts/*/*.{sh,pl,nim} "$ROOTDIR"/tests/scripts/*.sh; do
		dir=${f%/*}
		dir="${dir/$ROOTDIR/}"
		[[ -n "$dir" ]] && dir=" ${DIM}$dir${NC}"
		filename="${f##*/}"
		[[ ! -x "$f" ]] && echo -e " $X_MARK $filename$dir" && ((c=c+1))
	done
	[[ "$c" == 0 ]] && echo -e " $CHECK_MARK All scripts are executable."
	echo ""
fi

# Get list of staged files. [https://stackoverflow.com/a/33610683]
STAGED_FILES=$(git diff --name-only --cached)

# If no files are staged then exit.
if [[ -z "$STAGED_FILES" ]]; then
	if [[ $(isset "$PRINT") ]]; then
		echo -e "${BOLD}[Binary Executables]${NC}"
	fi

	if [[ $(isset "$PRINT") ]]; then
		echo -e " $CHECK_MARK [skipped] No staged binaries."
		echo ""
	fi

	exit 0
fi

# Read staged files list into an array.
readarray -t list <<< "$STAGED_FILES" # [https://stackoverflow.com/a/19772067]

# Declare empty array to contain unexecutable binaries.
declare -a binaries # [https://stackoverflow.com/a/41108078]

# Loop over files list.
for file in "${list[@]}"; do # [https://www.cyberciti.biz/faq/bash-for-loop-array/]
	# If file is macOS/Linux binary check that's executable.
	# [https://unix.stackexchange.com/a/340485]
	if [[ "$file" =~ \.(macosx|linux)$ ]]; then
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
		echo -e "${BOLD}[Binary Executables]${NC}"
	fi

	if [[ $(isset "$PRINT") ]]; then
		for binfile in "${binaries[@]}"; do		
			echo -e " $X_MARK Make executable: ${BTURQ}$binfile${NC}"
		done
	fi
	
	echo ""
	exit 1 # Give error to stop git.
fi

# If this block gets is there were no staged binaries so give message.
if [[ $(isset "$PRINT") ]]; then
	echo -e "${BOLD}[Binary Executables]${NC}"
fi

if [[ $(isset "$PRINT") ]]; then
	echo -e " $CHECK_MARK No staged binaries."
	echo ""
fi

exit 0
