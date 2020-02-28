#!/bin/bash

vmajor=${BASH_VERSINFO[0]}
vminor=${BASH_VERSINFO[1]}
if [[ "$vmajor" -ge 4 ]]; then
	if [[ "$vmajor" -eq 4 && "$vminor" -le 2 ]]; then return; fi
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
		# Ignore parent dir: [https://stackoverflow.com/a/11071654]
		# Get registry directories list.
		dirlist="$(find "$registrypath" -maxdepth 1 -mindepth 1 -type d -name "[!.]*")"
		# If registry is empty return.
		if [[ "$registrypath" == "$dirlist" ]]; then return; fi

		# Loop over map definition files to source them.
		for filepath in $dirlist; do
			# dir=${filepath%/*}
			filename="${filepath##*/}"
			command="${filename%%.*}"

			# If command is empty or acdef file doesn't exist skip.
			if [[ -z "$command" || ! -e "$filepath/$command.acdef" ]]; then continue; fi

			command="${command##*/}"
			# If filename doesn't equal command name there could be
			# invalid characters in name. In which case, skip it.
			if [[ "$filename" != "$command" ]]; then continue; fi
			# Register command/completion-script to bash-completion.
			source "$acscript" "$command"
		done
	fi
fi
