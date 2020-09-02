#!/bin/bash

# Initialization variables:
#
# cline    # CLI input.
# cpoint   # Index of caret position when [TAB] key was pressed.
# command  # Program for which completions are for.
# acdef    # The command's .acdef file contents.

output="$("$HOME/.nodecliac/registry/$command/hooks/pre-parse.pl" "$cline")"

# Lines are package.json's script entries.
acdef+=$'\n'"$output"
