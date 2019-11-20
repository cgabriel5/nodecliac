#!/bin/bash

# If binary files (ac.macosx or ac.linux) are staged this script
# checks whether the file(s) are executable. If not the script fails.

# -----------------------------------------------------------------CLI-ARGUMENTS

LOG_SILENT=0
SKIP_HEADER=0

while getopts 'sh' flag; do
	case "$flag" in
		s) LOG_SILENT=1 ;;
		h) SKIP_HEADER=1 ;;
	esac
done

# Get path of current script. [https://stackoverflow.com/a/246128]
__filepath="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# -----------------------------------------------------------------------IMPORTS

. "$__filepath/common.sh" # Import functions/variables.

# --------------------------------------------------------------------------VARS

# If no files are staged then exit.
if [[ -z "$STAGED_FILES" ]]; then
	# Print header.
	if [[ "$LOG_SILENT" == 0 && "$SKIP_HEADER" == 0 ]]; then
		echo -e "\033[1m[Binary Executables]\033[0m"
	fi

	if [[ "$LOG_SILENT" == 0 ]]; then
		echo -e " $CHECK_MARK [skipped] No staged binaries."
		echo ""
	fi

	exit 0
fi

# Read staged files list into an array.
readarray -t list <<<"$STAGED_FILES" # [https://stackoverflow.com/a/19772067]

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
	# Print header.
	if [[ "$LOG_SILENT" == 0 && "$SKIP_HEADER" == 0 ]]; then
		echo -e "\033[1m[Binary Executables]\033[0m"
	fi

	if [[ "$LOG_SILENT" == 0 ]]; then
		for binfile in "${binaries[@]}"; do		
			echo -e " $X_MARK Make executable: \033[1;36m$binfile\033[0m"
		done
	fi
	
	echo ""
	exit 1 # Give error to stop git.
fi

# If this block gets is there were no staged binaries so give message.
# Print header.
if [[ "$LOG_SILENT" == 0 && "$SKIP_HEADER" == 0 ]]; then
	echo -e "\033[1m[Binary Executables]\033[0m"
fi

if [[ "$LOG_SILENT" == 0 ]]; then
	echo -e " $CHECK_MARK No staged binaries."
	echo ""
fi

exit 0
