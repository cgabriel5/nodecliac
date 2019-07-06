#!/bin/bash

# Previously the '__getpkg_filepath' function from main.sh. Function logic
# now has its own file to use in other files as well.

# Get arguments.
oinput="$1" # → $NODECLIAC_INPUT_ORIGINAL
useglobal_pkg="$2" # → Whether to use/look for global yarn package.json.

# Store package.json JSON data and file path.
# Modifying global vars: [https://stackoverflow.com/q/23564995]
cwd="$PWD"
cache_path=""
package_dot_json=""
field_type="object"
declare opt OPTARG # OPTIND

# Find package.json file path.

# If no global parameter then look for local package.json.
if [[ ! -n "$useglobal_pkg" ]]; then
	# [https://stackoverflow.com/a/19031736]
	# [http://defindit.com/readme_files/perl_one_liners.html]
	# [https://www.perlmonks.org/?node_id=1004245]
	# Get workspace name if auto-completing workspace.
	# [https://askubuntu.com/questions/678915/whats-the-difference-between-and-in-bash]
	workspace="`LC_ALL=C perl -ne 'print "$1" if /^[ \t]*yarn[ \t]+workspace[ \t]+([a-zA-Z][-_a-zA-Z0-9]*)[ \t]*.*/' <<< "$oinput"`"

	# If workspace flag is set then we are auto-completing a workspace.
	if [[ -n "$workspace" ]]; then
		cwd="$PWD/$workspace" # Therefore, reset CWD to workspace's location.

		# Check for package.json file in workspace directory.
		package_dot_json="$cwd/package.json"
		if [[ ! -f "$package_dot_json" ]]; then
			# If file does not exist clear variable.
			package_dot_json=""
		fi
	else
		# '-n' documentation:
		# [https://stackoverflow.com/a/3601734]
		# [https://linuxconfig.org/how-to-test-for-null-or-empty-variables-within-bash-script]
		# [https://likegeeks.com/sed-linux/]
		#
		# Whichever comes first use, either cache file or package.json.
		while [[ -n "$cwd" ]]; do
			# Set cache directory path.
			if [[ ! -n "$cache_path" && -d "$cwd/.nodecliac-yarn.cache" ]]; then
				cache_path="$cwd/.nodecliac-yarn.cache"; break; fi
			# Set package.json file path.
			if [[ ! -n "$package_dot_json" && -f "$cwd/package.json" ]]; then
				package_dot_json="$cwd/package.json"; break; fi

			# Stop loop at node_modules directory.
			if [[ -d "$cwd/node_modules" ]]; then break; fi

			# Continuously chip away last level of PWD.
			cwd="${cwd%/*}"
		done

		# If cache exists try it first.
		if [[ -n "$cache_path" ]]; then
			# Get the last used package.json file path.
			package_dot_json=`<"$cache_path/pkgfilepath"`

			# If the file does not exist or the last and current modified times
			# don't match then package.json has been modified so clear variable.
			if [[ ! -f "$package_dot_json" ||
				# Get modified time: [https://stackoverflow.com/a/45955855]
				`<"$cache_path/lastmodtime"` != `stat -c %Y "$package_dot_json"` ]]; then
				cache_path=""
				package_dot_json=""
			fi
		fi

		# If there is no cache then get look for package.json file path.
		if [[ ! -n "$cache_path" ]]; then
			# The cache directory path.
			cache_path="${package_dot_json%/*}/.nodecliac-yarn.cache"
			mkdir -p "$cache_path" # Create the cache folder.
			# Create cache files.
			echo "$package_dot_json" > "$cache_path/pkgfilepath"
			echo `stat -c %Y "$package_dot_json"` > "$cache_path/lastmodtime"
		fi
	fi
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
echo "$field_type:$package_dot_json:$cache_path"
