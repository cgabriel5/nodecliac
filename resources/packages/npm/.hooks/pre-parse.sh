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
# [https://www.computerhope.com/unix/bash/mapfile.htm]
# [https://stackoverflow.com/a/10985980]
mapfile -ts1 lines < <(echo -e "$output")
# [https://stackoverflow.com/a/53839433]
printf -v output '%s\n' "${lines[@]}" && acdef+=$'\n'"$output"
