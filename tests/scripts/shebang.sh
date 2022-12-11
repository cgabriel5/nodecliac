#!/bin/bash

# Script will rewrite Bash shebangs to the latest Bash on the user's system.
# 
# This is more an issue with macOS. macOS comes with a dated version of Bash
# (v3.x.x) and seeing that v4.3+ is required some things might not work as
# intended. Therefore this script goes through all the Bash shells and uses
# the first version that is 4.3+, takes its path, and rewrites all shell
# scripts shebangs with that Bash interpreters path.
# 
# This is not an issue with Ubuntu, however. Ubuntu uses an up to date version
# of Bash and its default location is /bin/bash. When Bash is updated on macOS,
# with homebrew for example, the new Bash shell gets placed at /usr/local/bin/bash. 
# So for macOS if a Bash v4.3+ is found the shebangs will get re-written to
# use the updated Bash version.
# 
# Note: This could all be avoided by using the shebang: #!/usr/bin/env bash
# However, it has some drawbacks. For one, this poses some security concerns
# when the path is not explicitly provided/hard-coded.
# [https://stackoverflow.com/a/16365367], [https://unix.stackexchange.com/a/206366].
# Secondly, providing additional arguments to the interpreter is sometimes
# not allowed: [https://stackoverflow.com/a/16365367].
# More reading:
# [https://www.reddit.com/r/linuxadmin/comments/975nok/binbash_vs_usrbinenv_bash/e46xh7y/]
# 
# Note: This script runs automatically post npm/yarn install.
# 
# Bash locations per OS:
# Ubuntu: /bin/bash
# macOS: /bin/bash, /usr/local/bin/bash
# 
# Resources:
# [https://unix.stackexchange.com/a/206357]
# [https://stackoverflow.com/a/58270646]

# Get path of current script. [https://stackoverflow.com/a/246128]
__filepath="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# ---------------------------------------------------------------------- IMPORTS

. "$__filepath/common.sh"

# ------------------------------------------------------------------------- VARS

# Get list of valid Bash login shells: [https://stackoverflow.com/a/58270646]
list=$(grep "/bin/bash$" <<< cat /etc/shells)

# Split lines into array.
# readarray -t shells <<< "$list" # [https://stackoverflow.com/a/19772067]
IFS=$'\n' read -rd '' -a shells <<< "$list"

ROOTDIR=$(chipdir "$__filepath" 2) # Get the project's root directory.

valid_bash="" # Path to valid 4.3+ version of path.

# Loop over shell paths.
for ((i=${#shells[@]}-1; i>=0; i--)); do # [https://unix.stackexchange.com/a/27400]
	path="${shells[$i]}"

	# [https://stackoverflow.com/a/9450628]
	version=$(perl -ne 'if (/ version ([\.\d]{3,})/) { print "$1"; }' <<< "$("$path" --version)")

	# Validate version number (must be >= 4.3).
	if [[ $(perl -ne 'print 1 if $_ =~ /^([4-9]\.([3-9])|[5-9]\.\d).*$/' <<< "$version") ]]; then
		valid_bash="$path"; break # Set valid Bash path and exit loop.
	fi
done

# If a valid Bash path exists reset all Bash shebangs.
if [[ -n "$valid_bash" ]]; then
	# [https://stackoverflow.com/a/15736463]
	# [https://askubuntu.com/a/318211]
	# [https://askubuntu.com/a/749708]
	# [https://superuser.com/a/397325]
	# [https://stackoverflow.com/a/5927391]
	# [https://stackoverflow.com/a/14132309]
	# Get list of files to run shebang change on.
	files="$(
		find "$ROOTDIR" -type f \
		-name '*.sh' \
		! -path '*/\.*' \
		! -path '*/bin/*' \
		! -path '*/config*/*' \
		! -path '*/resources/*' \
		! -path '*/node_modules/*' \
		! -path '*/sublime-text/*' \
		! -path '*.lock' \
		! -path '*.nim' \
		! -path '*.js*' \
		! -path '*.pl' \
		! -path '*.acdef' \
		! -path '*.acmap' \
		! -path '*.md' \
		! -path '*.t*xt' \
		! -path '*.gif' # | cut -c3-
	)"

	# EROOTDIR=${ROOTDIR//\//\\/} # Escape '/' in path.
	# [https://stackoverflow.com/a/20528931]
	# files="$(perl -pe "s/^/$EROOTDIR\//" <<< "$files")"

	# [https://stackoverflow.com/questions/4205564/unix-change-the-interpreter-line-in-all-shell-scripts]
	# [https://unix.stackexchange.com/questions/313009/sed-usage-add-shebang-missing-from-first-line-of-script]
	# [https://www.perlmonks.org/?node_id=151267]
	# [https://stackoverflow.com/a/28035653]
	# [https://gist.github.com/joyrexus/7328094]
	# perl -i -ne "if (\$. == 1 and /^#!\/.*\/bash$/) { print \"#!$valid_bash\\n\" } else { print \$_ }; $. = 0 if eof" $files
	if [[ -n "$files" ]]; then
		perl -i -ne "if (\$. == 1 and /^#!\/.*\/bash$/) { print \"#!$valid_bash\\n\" } else { print \$_ }; $. = 0 if eof" $files
	fi

	# GNU grep method (different output in macOS):
	# [https://unix.stackexchange.com/a/355388]
	# [https://unix.stackexchange.com/a/66098]
	# [https://stackoverflow.com/a/8692318]
	# [https://unix.stackexchange.com/a/158639]
	# [https://askubuntu.com/a/996457]
	# [https://unix.stackexchange.com/a/282650]
	# Remove './' from output: [https://stackoverflow.com/a/57799282]
	# grep -R --exclude-dir={node_modules,bin,resources,.git*,._*} --exclude='.*' -rl '^#!/bin*' .
fi
