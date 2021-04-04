#!/bin/bash

# Initialization variables:
#
# cline    # CLI input.
# cpoint   # Index of caret position when [TAB] key was pressed.
# command  # Program for which completions are for.
# acdef    # The command's .acdef file contents.

# Only run script when there are exactly 2 words before caret. The prehook
# script is only needed in that condition. This prevents running another
# process when it is not necessary (potentially slowing down completions).
if [[ "${#COMP_WORDS[@]}" -eq 2 ]]; then
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
fi
