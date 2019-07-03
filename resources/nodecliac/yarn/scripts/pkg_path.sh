#!/bin/bash

# Previously the '__getpkg_filepath' function from main.sh. Function logic
# now has its own file to use in other files as well.

# Store package.json JSON data and file path.
# Modifying global vars: [https://stackoverflow.com/q/23564995]
package_dot_json=""
field_type="object"

# Get arguments.
oinput="$1" # → $NODECLIAC_INPUT_ORIGINAL
useglobal_pkg="$2" # → Whether to use/look for global yarn package.json.

# Find package.json file path.

# Declare variables.
declare cwd="$PWD" opt OPTARG # OPTIND

# [https://stackoverflow.com/a/19031736]
# [http://defindit.com/readme_files/perl_one_liners.html]
# [https://www.perlmonks.org/?node_id=1004245]
# Get workspace name if auto-completing workspace.
workspace=$(echo "$oinput" | perl -ne 'print "$1" if /^[ \t]*yarn[ \t]+workspace[ \t]+([a-zA-Z][-_a-zA-Z0-9]*)[ \t]*.*/')

# If workspace flag is set then we are auto-completing a workspace.
# Therefore, reset CWD to workspace's location.
if [[ ! -z "$workspace" ]]; then cwd="$PWD/$workspace"; fi

# If no global parameter then look for local package.json.
if [[ -z "$useglobal_pkg" ]]; then
	# '-n' documentation:
	# [https://stackoverflow.com/a/3601734]
	# [https://linuxconfig.org/how-to-test-for-null-or-empty-variables-within-bash-script]
	# [https://likegeeks.com/sed-linux/]
	while [[ -n "$cwd" ]]; do
		if [[ -f "$cwd/package.json" ]]; then
			package_dot_json="$cwd/package.json"
			break
		fi
		cwd="${cwd%/*}"
	done
else # Else look for global yarn package.json.
	if [[ -f "$HOME/.config/yarn/global/package.json" ]]; then
		package_dot_json="$HOME/.config/yarn/global/package.json"
	elif [[ -f "$HOME/.local/share/yarn/global/package.json" ]]; then
		package_dot_json="$HOME/.local/share/yarn/global/package.json"
	elif [[ -f "$HOME/.yarn/global/package.json" ]]; then
		package_dot_json="$HOME/.yarn/global/package.json"
	else
		package_dot_json=""
	fi

	# [https://unix.stackexchange.com/a/214151]
	# shift $((OPTIND - 1))

	# while getopts ":g:" opt; do
	# 	case $opt in
	# 		g)
	# 			if [[ -f "$HOME/.config/yarn/global/package.json" ]]; then
	# 				package_dot_json="$HOME/.config/yarn/global/package.json"
	# 			elif [[ -f "$HOME/.local/share/yarn/global/package.json" ]]; then
	# 				package_dot_json="$HOME/.local/share/yarn/global/package.json"
	# 			elif [[ -f "$HOME/.yarn/global/package.json" ]]; then
	# 				package_dot_json="$HOME/.yarn/global/package.json"
	# 			else
	# 				package_dot_json=""
	# 			fi
	# 			;;
	# 		# t)
	# 		# 	case "$OPTARG" in
	# 		# 		array|boolean|number|object|string)
	# 		# 			field_type="$OPTARG"
	# 		# 			;;
	# 		# 	esac
	# 		# 	;;
	# 	esac
	# done
	# # [https://unix.stackexchange.com/a/214151]
	# # shift $((OPTIND - 1))
fi

# Return a single line in following format:
echo "$field_type:$package_dot_json"
