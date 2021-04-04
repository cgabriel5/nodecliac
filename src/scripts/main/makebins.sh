#!/usr/bin/env bash

# This script compiles --genScript packages in the current directory
# and is primarily meant to be used for macosx cross-compilation but
# can also be used for linux cross-compilation as well.

# [https://unix.stackexchange.com/a/324181]
# [https://stackoverflow.com/a/19327286]
[[ "$OSTYPE" =~ (^[^0-9-]+) ]]
os="${BASH_REMATCH[1]/darwin/macosx}"

# [https://stackoverflow.com/a/246128]
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
mkdir "$root/bins"

while read -r dir; do
	cscript="$(find "$dir" -type f -name "compile_*.sh")"
	if [[ -e "$cscript" ]]; then
		[[ ! -x "$cscript" ]] && chmod +x "$cscript"
		pushd "$dir" < /dev/null > /dev/null
		"$cscript"
		binary="$(find "$dir" -name "*.$os")"
		[[ -e "$binary" ]] && cp -pr "$binary" "$root/bins"
		popd < /dev/null > /dev/null
		echo -e "\033[32msuccess\033[0m: Compiled $(basename "$binary")"
	fi
done < <(find "$root" -maxdepth 1 -mindepth 1 \( -type d -o -type l \) -name "[!.]*")
