#!/bin/bash

# Prehook script gets provided the following arguments:
# $1 => $cline        # Original (complete) CLI input.
# $2 => $cpoint       # Caret index when [tab] key was pressed.
# $3 => $maincommand  # The ACDEF definitions file.
# $4 => $acdef        # The command name from sourced passed-in argument.

# This script will run the Perl prehook script. The returned data is in the
# following format: the 1st line is the modified CLI input while subsequent
# lines are addons to the ACDEF.
output=`"$HOME/.nodecliac/registry/yarn/hooks/prehook.pl" "$1"`

# Get modified CLI input line (1st line).
# [https://stackoverflow.com/q/30649640]
firstline=`LC_ALL=C perl -npe "exit if $. > 1" <<< "$output"`
if [[ -n "$firstline" ]]; then cline="$firstline"; fi

# Get ACDEF addon entries.
addon=`LC_ALL=C perl -ne "print if $. > 1" <<< "$output"`
if [[ -n "$addon" ]]; then acdef+=$'\n'"$addon"; fi
