#!/bin/bash

# Prehook script gets provided the following arguments:
# $1 => $cline        # Original (complete) CLI input.
# $2 => $cpoint       # Caret index when [tab] key was pressed.
# $3 => $maincommand  # The acdef definitions file.
# $4 => $acdef        # The command name from sourced passed-in argument.

# The script will run the needed Perl scripts and return the modified output.

# Run input hook script.
output=`"$HOME/.nodecliac/registry/yarn/hooks/input.pl" "$1"`
# Reset variable if output exists.
if [[ ! -z "$output" ]]; then cline="$output"; fi

# Run acdef hook script.
output=`"$HOME/.nodecliac/registry/yarn/hooks/acdef.pl" "$1" "$4"`
# Reset variable if output exists.
if [[ ! -z "$output" ]]; then acdef="$4$output"; fi
