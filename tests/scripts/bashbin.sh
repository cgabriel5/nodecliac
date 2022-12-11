#!/usr/local/bin/bash

# This script contains a function that attempts to finds all installed Bash
# shells and returns the first Bash shell that is version 4.3+. If none
# are found, an empty string is returned.

bashpath () {
	binpath=""
	
	while IFS= read path; do
		# [https://stackoverflow.com/a/9450628]
		# [https://stackoverflow.com/a/1336245]
		version="$("$path" -c 'IFS=".";echo "${BASH_VERSINFO[*]:0:2}"')"
		# Validate version number (must be >= 4.3).
		[[ "$version" =~ ^([4-9]\.([3-9])|[5-9]\.[0-9]{1,})$ ]] && \
			binpath="$path" && break
	done <<< "$(grep "/bin/bash$" <<< cat /etc/shells)" # [[https://stackoverflow.com/a/58270646]]

	echo "$binpath"
}
