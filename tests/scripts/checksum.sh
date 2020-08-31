#!/bin/bash

# Checks to see if installer.sh checksum is current in README.md.

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
# Read staged files list into an array.
readarray -t list <<< "$STAGED_FILES" # [https://stackoverflow.com/a/19772067]

ROOTDIR=$(chipdir "$__filepath" 2) # Get the project's root directory.
checksum="$("$ROOTDIR/src/scripts/main/checksum.sh")"

# Declare empty array to contain unexecutable binaries.
declare -a files # [https://stackoverflow.com/a/41108078]

# Loop over files list.
for file in "${list[@]}"; do # [https://www.cyberciti.biz/faq/bash-for-loop-array/]
	# If file is macOS/Linux binary check that's executable.
	# [https://unix.stackexchange.com/a/340485]
	if [[ "$file" =~ ^(installer.sh|README.md)$ ]]; then
		filepath="$ROOTDIR/$file" # The file's complete path.

		# If file is not executable exit with error.
		# [https://stackoverflow.com/a/49707794]
		if [[ ! -e "$filepath" || ! -x $(realpath "$filepath") ]]; then
			files+=($(basename "$file")) # [https://stackoverflow.com/a/1951523]
		fi
	fi
done

[[ $(isset "$PRINT") ]] && echo -e "${BOLD}[Installer Checksum]${NC}"

# Ensure installer checksum is current.

# If the file does not contain current checksum...
# [https://stackoverflow.com/a/57158235]
if ! grep -q "$checksum" "$ROOTDIR/README.md"; then
	# Check if current checksum if staged...
	if [[ ${#files[@]} -ne 0 ]]; then
		# [https://stackoverflow.com/a/12294939]
		diff="$(git diff --staged --word-diff  "$ROOTDIR/README.md")"
		if [[ -n "$diff" ]]; then
			if [[ "$diff" != *"$checksum"* ]]; then
				echo -e " $X_MARK Installer checksum not current. Run '$ yarn run checksum'."
				echo ""
			else
				# There must be two occurrences.
				# [https://stackoverflow.com/a/2912711]
				if [[ $(grep -Fco "$checksum" <<< "$diff") > 1 ]]; then
					echo -e " $CHECK_MARK Current checksum staged."
					echo ""
					exit 0
				fi
			fi
		fi
	fi

	if [[ $(isset "$PRINT") ]]; then
		echo -e " $X_MARK Installer checksum not current. Run '$ yarn run checksum'."
		echo ""
	fi

	# If array is populated there are errors. # [https://serverfault.com/a/477506]	
	[[ ${#files[@]} -ne 0 ]] && exit 1 # Give error to stop git.
else
	# There must be two occurrences.
	# [https://stackoverflow.com/a/2912711]
	occurrences=$(grep -Fco "$checksum" "$ROOTDIR/README.md")
	if [[ $occurrences  < 2 ]]; then
		echo -e " $X_MARK Checksum occurrences found: $occurrences."
		echo ""
		exit 1
	fi

	if [[ $(isset "$PRINT") ]]; then
		echo -e " $CHECK_MARK Installer checksum current."
		echo ""
	fi
fi

exit 0
