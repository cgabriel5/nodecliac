#!/usr/local/bin/bash

# This script contains a function that attempts to finds all installed Bash
# shells and returns the first Bash shell that is version 4.3+. If none
# are found, an empty string is returned.

bashpath () {
	# Get list of valid Bash login shells: [https://stackoverflow.com/a/58270646]
	list=$(grep "/bin/bash$" <<< cat /etc/shells)

	# Split lines into array.
	# readarray -t shells <<< "$list" # [https://stackoverflow.com/a/19772067]
	IFS=$'\n' read -rd '' -a shells <<< "$list"

	binpath="" # Path to valid 4.3+ version of path.

	# Loop over shell paths.
	for path in ${shells[*]}; do
		# [https://stackoverflow.com/a/9450628]
		# [https://stackoverflow.com/a/1336245]
		version="$($path -c 'IFS=".";echo "${BASH_VERSINFO[*]:0:2}"')"
		# version=$(perl -ne 'if (/ version ([\.\d]{3,})/) { print "$1"; }' <<< "$("$path" --version)")
		# /usr/local/bin/bash -c 'echo "${BASH_VERSINFO:-0}"'
		# /bin/bash -c 'echo "${BASH_VERSINFO:-0}"'
		# /usr/bin/env bash -c 'echo "${BASH_VERSINFO:-0}"'
		# /bin/bash -c 'IFS=".";echo "${BASH_VERSINFO[*]:0:2}"' # [https://stackoverflow.com/a/1336245]

		# Validate version number (must be >= 4.3).
		[[ "$version" =~ ^([4-9]\.([3-9])|[5-9]\.[0-9]{1,})$ ]] && binpath="$path" && break

		# # Validate version number (must be >= 4.3).
		# if [[ $(perl -ne 'print 1 if $_ =~ /^([4-9]\.([3-9])|[5-9]\.\d).*$/' <<< "$version") ]]; then
		# 	binpath="$path"; break # Set valid Bash path and exit loop.
		# fi
	done

	echo "$binpath"
}
