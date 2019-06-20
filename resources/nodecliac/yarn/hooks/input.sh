#!/bin/bash

# # Get repo script names.
# scriptpath=~/.nodecliac/commands/yarn/scripts/main.sh
# # Run completion script if it exists.
# if [[ -f "$scriptpath" ]]; then
# 	output=`"$scriptpath" "workspace"`

	# Get repo script names.
	scriptpath=~/.nodecliac/commands/yarn/hooks/input.pl
	if [[ -f "$scriptpath" ]]; then
		output=`"$scriptpath"`

		# Return script names.
		echo -e "\n$output"
	fi
# fi
