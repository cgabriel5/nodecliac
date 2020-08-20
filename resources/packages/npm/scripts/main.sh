#!/bin/bash

action="$1"
usedflags="$NODECLIAC_USED_FLAGS"
useglobal=0

IFS=',' read -ra flags <<< "$usedflags"
for f in "${flags[@]}"; do
	[[ " -g --global " == *" $f "* ]] && useglobal=1 && break
done

if [[ "$useglobal" == 0 ]]; then
	echo -e "$("$HOME/.nodecliac/registry/npm/scripts/main.pl")"
else
	# for f in "$ndir"/*; do
	# for f in "$(npm root -g)"/*; do
	for f in /opt/node/lib/node_modules/*; do
		echo "$(basename -- $f)";
	done
fi

