#!/bin/bash

# Run input hook script.
output=`"$HOME/.nodecliac/registry/yarn/hooks/input.pl" "$1"`
# Reset variable if output exists.
if [[ ! -z "$output" ]]; then cline="$output"; fi

# Run acdef hook script.
output=`"$HOME/.nodecliac/registry/yarn/hooks/acdef.pl" "$1" "$4"`
# Reset variable if output exists.
if [[ ! -z "$output" ]]; then acdef="$4$output"; fi
