#!/bin/bash

# # Get platform name.
# #
# # @return {string} - User's platform.
# #
# # @resource [https://stackoverflow.com/a/18434831]
# function __platform() {
# 	case "$OSTYPE" in
# 	  solaris*) echo "solaris" ;;
# 	  darwin*)  echo "osx" ;;
# 	  linux*)   echo "linux" ;;
# 	  bsd*)     echo "bsd" ;;
# 	  msys*)    echo "windows" ;;
# 	  *)        echo "unknown" ;;
# 	esac
# }

# # Checks whether command exists.
# #
# # @param {string} 1) - Command name.
# # @return {string} - Command path if exists.
# #
# # @resource [https://stackoverflow.com/a/677212]
# function __exists() {
# 	echo `command -v "$1"`
# }

# # Get default sed path + platform.
# sed_command=`__exists sed`
# platform=`__platform`

# # If on macOS/OS X check for sed version. Must have GNU version.
# if [[ "$platform" == "osx" ]]; then
# 	# Check manual for sed flavor.
# 	# [https://unix.stackexchange.com/a/27111]
# 	sed_flavor="$(grep -o -m1 -e "BSD" -e "GNU" <<< `man sed` | head -1)"
# 	if [[ "$sed_flavor" == "BSD" ]]; then
# 		# Check for GNU version.
# 		gnu_sed="/usr/local/bin/gsed"
# 		if [[ ! -f "$gnu_sed" ]]; then
# 			hdr="[nodecliac]:" # Line decor header.
# 			# No GNU sed command found so return.
# 			echo "${hdr}: BSD sed version found but GNU version required."
# 			echo "${hdr}: -- Script registration aborted."
# 			echo "${hdr}: GNU sed can be installed with homebrew like so:"
# 			echo "${hdr}: $ brew install coreutils gnu-sed"
# 			return
# 		else
# 			# Reset command to use gsed.
# 			sed_command="$gnu_sed"
# 		fi
# 	fi
# fi

# # Export needed data to access in completion script.
# # [https://stackoverflow.com/a/9772093]
# export __nodecliac_env="$platform:$sed_command"

# # Return if nodecliac is disabled.
# if [[ -f "$HOME/.nodecliac/.disable" ]]; then return; fi

# Get version information.
vmajor=${BASH_VERSINFO[0]}
vminor=${BASH_VERSINFO[1]}

# Bash version must be 4.3+ to register completion scripts to commands.
if [[ "$vmajor" -ge 4 ]]; then
	# If bash is version 4 then it must be at least 4.3.
	if [[ "$vmajor" -eq 4 && "$vminor" -le 2 ]]; then return; fi

	# Continue if version is at least 4.3...

	registrypath=~/.nodecliac/registry
	acscript="$HOME/.nodecliac/src/main/connector.sh"
	if [[ -f "$acscript" ]]; then
		# [https://superuser.com/a/352387]
		# [https://askubuntu.com/a/427290]
		# [https://askubuntu.com/a/1137769]
		# [https://superuser.com/a/1404146]
		# [https://superuser.com/a/999448]
		# [https://stackoverflow.com/a/9612232]
		# [https://askubuntu.com/a/318211]
		# Get registry directories list.
		dirlist="$(find "$registrypath" -maxdepth 1 -type d -name "[!.]*")"

		# If registry is empty return from script. Ignores any files (including hidden ones).
		if [[ "$registrypath" == "$dirlist" ]]; then return; fi

		# Loop over map definition files to source them.
		# [https://stackoverflow.com/a/43606356]
		for filepath in $dirlist; do
			# # Ignore config files.
			# if [[ "$filepath" == *".config.acdef" ]]; then continue; fi

			# Get dir and filename.
			# dir=${filepath%/*}
			# Get filename from file path.
			filename="${filepath##*/}"
			# Get command name (everything up to first period).
			command="${filename%%.*}"

			# Only register script to command if command exists in filename
			# and if .acdef file exists for the comment.
			if [[ -n "$command" && -e "$filepath/$command.acdef" ]]; then
				# If command exists then register completion script to command.
				# Note: Command is provided to script as the first parameter.
				source "$acscript" "${command##*/}"
			fi
		done
	fi
fi
