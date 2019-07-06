#!/bin/bash

# Prehook script gets provided the following arguments:
# $1 => $cline        # Original (complete) CLI input.
# $2 => $cpoint       # Caret index when [tab] key was pressed.
# $3 => $maincommand  # The acdef definitions file.
# $4 => $acdef        # The command name from sourced passed-in argument.

# The script will run the needed Perl scripts and return the modified output.

# Note: The first line of the output will be the modified CLI input. All
# lines after will be the new line to add to the acdef.
output=`"$HOME/.nodecliac/registry/yarn/hooks/prehook.pl" "$1"`

# First line is meta info (completion type, last word, etc.).
firstline=`LC_ALL=C perl -pe "exit if $. > 1" <<< "$output"`
# [https://stackoverflow.com/q/30649640]
if [[ -n "$firstline" ]]; then cline="$firstline"; fi

# Get acdef addon entries.
addon=`LC_ALL=C perl -ne "print if $. > 1" <<< "$output"`
if [[ -n "$addon" ]]; then acdef+=$'\n'"$addon"; fi
