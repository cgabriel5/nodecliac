#!/bin/bash

# Script has access to connector.sh variables. If changes need to be made
# use the following and change them accordingly:
# $COMP_LINE    # Original (complete) CLI input.
# $cpoint       # Caret index when [tab] key was pressed.
# $maincommand  # The ACDEF definitions file.
# $acdef        # The command name from sourced passed-in argument.

# This script will run the Perl prehook script. The returned data is in the
# following format: the 1st line is the modified CLI input while subsequent
# lines are addons to the ACDEF.
output=$("$HOME/.nodecliac/registry/yarn/hooks/prehook.pl" "$COMP_LINE")

# Get modified CLI input line (1st line).
# [https://stackoverflow.com/q/30649640]
# firstline=$(LC_ALL=C perl -npe "exit if $. > 1" <<< "$output")
read -r firstline <<< "$output"
if [[ -n "$firstline" ]]; then cline="$firstline"; fi

# Get ACDEF addon entries.
# addon=$(LC_ALL=C perl -ne "print if $. > 1" <<< "$output")
# [https://stackoverflow.com/a/24542788]
# addon=$(awk 'NR>1' <<< "$output")

# Remove first line from output. Remaining text, if any, is the ACDEF output.
len="${#firstline}"
# If length is zero, reset length to 1 to remove starting new line.
if [ $len == 0 ]; then len=1; fi
addon="${output:$len}"
if [[ -n "$addon" ]]; then acdef+=$'\n'"$addon"; fi
