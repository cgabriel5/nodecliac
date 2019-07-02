#!/bin/bash

# Run prehook.pl script.

# Run perl script to get completions.
scriptpath=~/.nodecliac/registry/yarn/hooks/prehook.pl
# Run completion script if it exists.
if [[ -f "$scriptpath" ]]; then
	output=`"$scriptpath"`

	# Return script names.
	echo -e "\n$output"
fi
