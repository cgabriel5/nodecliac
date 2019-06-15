#!/bin/bash

# Get repo script names.
scriptpath=~/.nodecliac/commands/yarn/scripts/main.sh
# Run completion script if it exists.
if [[ -f "$scriptpath" ]]; then
	output=`"$scriptpath" "run"`

	# Get repo script names.
	scriptpath=~/.nodecliac/commands/yarn/hooks/acdef.pl
	if [[ -f "$scriptpath" ]]; then
		output=`"$scriptpath" "$output"`

		# Return script names.
		echo -e "\n$output"
	fi
fi