#!/usr/local/bin/bash

# Script generates a sha256 checksum of the install.sh script.

chipdir() {
	local dir="$1" # The provided directory path.
	# Remove last directory from path.
	for ((x=0; x<"$2"; x++)); do dir="${dir%/*}"; done
	echo "$dir" # Return modified path.
}

# Get path of current script. [https://stackoverflow.com/a/246128]
__filepath="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

root="$(chipdir "$__filepath" 3)"
is="$(cat "$root/install.sh")"
# [https://crypto.stackexchange.com/a/2146]
cs=($([[ "$OSTYPE" == "darwin"* ]] && shasum -a 256 <<< "$is" || sha256sum <<< "$is"))
perl -i -p -e "s/[a-z0-9]{64}/$cs/g" "$root/README.md"
echo "$cs"

exit 0
