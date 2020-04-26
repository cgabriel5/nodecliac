#!/bin/bash

# Initialization variables:
#
# cline    # CLI input.
# cpoint   # Index of caret position when [TAB] key was pressed.
# command  # Program for which completions are for.
# acdef    # The command's .acdef file contents.

output="$("$HOME/.nodecliac/registry/$command/hooks/pre-parse.pl" "$cline")"

# 1st line is the modified CLI (workspace) input.
read -r firstline <<< "$output"
[[ -n "$firstline" ]] && cline="$firstline"

# Remaining lines are package.json's script entries.
len="${#firstline}"; [[ ! "$len" ]] || len=1
addon="${output:$len}"; [[ -n "$addon" ]] && acdef+=$'\n'"$addon"
