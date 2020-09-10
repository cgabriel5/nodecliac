#!/bin/bash

# Initialization variables:
#
# cline    # CLI input.
# cpoint   # Index of caret position when [TAB] key was pressed.
# command  # Program for which completions are for.
# acdef    # The command's .acdef file contents.

# output="$("$HOME/.nodecliac/registry/$command/hooks/pre-parse.pl" "$cline")"
# [[ -n "$output" ]] && cline="$output"

# [https://unix.stackexchange.com/a/251016]
r="^[ \t]*?balena[ \t]+?help[ \t](.*)"
[[ "$cline" =~ $r ]] && cline="op ${BASH_REMATCH[1]}"
